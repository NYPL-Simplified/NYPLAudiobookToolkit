import AVFoundation

class OpenAccessPlayer: NSObject, Player {

    var errorDomain: String {
        return OpenAccessPlayerErrorDomain
    }
    
    var taskCompleteNotification: Notification.Name {
        return OpenAccessTaskCompleteNotification
    }
    
    var isPlaying: Bool {
        return self.avQueuePlayerIsPlaying
    }
    
    var isDrmOk: Bool {
        didSet(oldValue) {
            if !oldValue {
                pause()
                notifyDelegatesOfPlaybackFailureFor(chapter: self.chapterAtCurrentCursor, NSError(domain: errorDomain, code: OpenAccessPlayerError.drmExpired.rawValue, userInfo: nil))
                unload()
            }
        }
    }

    private var avQueuePlayerIsPlaying: Bool = false {
        didSet {
            if let location = self.currentChapterLocation {
                if oldValue == false && avQueuePlayerIsPlaying == true {
                    self.notifyDelegatesOfPlaybackFor(chapter: location)
                } else if oldValue == true && avQueuePlayerIsPlaying == false {
                    self.notifyDelegatesOfPauseFor(chapter: location)
                }
            }
        }
    }

    /// AVPlayer returns 0 for being "paused", but the protocol expects the
    /// "user-chosen rate" upon playing.
    var playbackRate: PlaybackRate = .normalTime {
        didSet {
            if self.avQueuePlayer.rate != 0.0 {
                let rate = PlaybackRate.convert(rate: self.playbackRate)
                self.avQueuePlayer.rate = rate
            }
        }
    }

    var currentChapterLocation: ChapterLocation? {
        let avPlayerOffset = self.avQueuePlayer.currentTime().seconds
        let playerItemStatus = self.avQueuePlayer.currentItem?.status
        let offset: TimeInterval
        if !avPlayerOffset.isNaN && playerItemStatus == .readyToPlay {
            offset = avPlayerOffset
        } else {
            offset = 0
        }
        return ChapterLocation(
            number: self.chapterAtCurrentCursor.number,
            part: self.chapterAtCurrentCursor.part,
            duration: self.chapterAtCurrentCursor.duration,
            startOffset: 0,
            playheadOffset: offset,
            title: self.chapterAtCurrentCursor.title,
            audiobookID: self.audiobookID
        )
    }

    var isLoaded = true

    func play()
    {
        // Check DRM
        if !isDrmOk {
            ATLog(.warn, "DRM is flagged as failed.")
            let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.drmExpired.rawValue, userInfo: nil)
            self.notifyDelegatesOfPlaybackFailureFor(chapter: self.chapterAtCurrentCursor, error)
            return
        }

        switch self.playerIsReady {
        case .readyToPlay:
            self.avQueuePlayer.play()
            let rate = PlaybackRate.convert(rate: self.playbackRate)
            if rate != self.avQueuePlayer.rate {
                self.avQueuePlayer.rate = rate
            }
        case .failed:
            ATLog(.error, "Ready status is \"failed\".")
            let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.unknown.rawValue, userInfo: nil)
            self.notifyDelegatesOfPlaybackFailureFor(chapter: self.chapterAtCurrentCursor, error)
            break
        case .unknown:
            fallthrough
        @unknown default:
            self.cursorQueuedToPlay = self.cursor
            ATLog(.error, "Player not yet ready. QueuedToPlay = true.")
            if self.avQueuePlayer.currentItem == nil {
                if let fileStatus = assetFileStatus(self.cursor.currentElement.downloadTask) {
                    switch fileStatus {
                    case .saved(let savedURL):
                        let item = AVPlayerItem(url: savedURL)
                        if self.avQueuePlayer.canInsert(item, after: nil) {
                            self.avQueuePlayer.insert(item, after: nil)
                        }
                    case .missing(_):
                        self.rebuildOnFinishedDownload(task: self.cursor.currentElement.downloadTask)
                    default:
                        break
                    }
                }
            }
        }
    }

    func pause()
    {
        if self.isPlaying {
            self.avQueuePlayer.pause()
        } else if self.cursorQueuedToPlay != nil {
            self.cursorQueuedToPlay = nil
            NotificationCenter.default.removeObserver(self, name: taskCompleteNotification, object: nil)
            notifyDelegatesOfPauseFor(chapter: self.chapterAtCurrentCursor)
        }
    }

    func unload()
    {
        self.isLoaded = false
        self.avQueuePlayer.removeAllItems()
        self.notifyDelegatesOfUnloadRequest()
    }

    func skipPlayhead(_ timeInterval: TimeInterval, completion: ((ChapterLocation)->())? = nil) -> ()
    {
        guard let currentLocation = self.currentChapterLocation else {
            ATLog(.error, "Invalid chapter information required for skip.")
            return
        }
        let currentPlayheadOffset = currentLocation.playheadOffset
        let chapterDuration = currentLocation.duration
        let adjustedOffset = adjustedPlayheadOffset(currentPlayheadOffset: currentPlayheadOffset,
                                                    currentChapterDuration: chapterDuration,
                                                    requestedSkipDuration: timeInterval)

        if let destinationLocation = currentLocation.update(playheadOffset: adjustedOffset) {
            movePlayhead(to: destinationLocation, shouldBeginAutoPlay: true)
            let newPlayhead = move(cursor: self.cursor, to: destinationLocation)
            completion?(newPlayhead.location)
        } else {
            ATLog(.error, "New chapter location could not be created from skip.")
            return
        }
    }

    /// New Location's playhead offset could be oustide the bounds of audio, so
    /// move and get a reference to the actual new chapter location. Only update
    /// the cursor if a new queue can successfully be built for the player.
    ///
    /// - Parameter newLocation: Chapter Location with possible playhead offset
    ///   outside the bounds of audio for the current chapter
    /// - Parameter shouldBeginAutoPlay: Passing in `true` will allow the player
    ///   to begin playing if player is originally in `pause` state and ready to play
    func movePlayhead(to location: ChapterLocation, shouldBeginAutoPlay: Bool)
    {
        let newPlayhead = move(cursor: self.cursor, to: location)

        guard let newItemDownloadStatus = assetFileStatus(newPlayhead.cursor.currentElement.downloadTask) else {
            let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.unknown.rawValue, userInfo: nil)
            notifyDelegatesOfPlaybackFailureFor(chapter: newPlayhead.location, error)
            return
        }

        switch newItemDownloadStatus {
        case .saved(_):
            // If we're in the same AVPlayerItem, apply seek directly with AVPlayer.
            if newPlayhead.location.inSameChapter(other: self.chapterAtCurrentCursor) {
                self.seekWithinCurrentItem(newOffset: newPlayhead.location.playheadOffset)
                return
            }
            // Otherwise, check for an AVPlayerItem at the new cursor, rebuild the player
            // queue starting from there, and then begin playing at that location.
            self.buildNewPlayerQueue(atCursor: newPlayhead.cursor) { (success) in
                if success {
                    self.cursor = newPlayhead.cursor
                    self.seekWithinCurrentItem(newOffset: newPlayhead.location.playheadOffset)
                    if shouldBeginAutoPlay {
                        self.play()
                    }
                } else {
                    ATLog(.error, "Failed to create a new queue for the player. Keeping playback at the current player item.")
                    let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.unknown.rawValue, userInfo: nil)
                    self.notifyDelegatesOfPlaybackFailureFor(chapter: location, error)
                }
            }
        case .missing(_):
            // TODO: Could eventually handle streaming from here.
            let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.downloadNotFinished.rawValue, userInfo: nil)
            notifyDelegatesOfPlaybackFailureFor(chapter: location, error)
            return
        case .unknown:
            let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.unknown.rawValue, userInfo: nil)
            notifyDelegatesOfPlaybackFailureFor(chapter: location, error)
            return
        }
    }

    /// Moving within the current AVPlayerItem.
    private func seekWithinCurrentItem(newOffset: TimeInterval)
    {
        guard let currentItem = self.avQueuePlayer.currentItem else {
            ATLog(.error, "No current AVPlayerItem in AVQueuePlayer to seek with.")
            return
        }
        if self.avQueuePlayer.currentItem?.status != .readyToPlay {
            ATLog(.debug, "Item not ready to play. Queueing seek operation.")
            self.queuedSeekOffset = newOffset
            return
        }
        currentItem.seek(to: CMTimeMakeWithSeconds(Float64(newOffset), preferredTimescale: Int32(1))) { finished in
            if finished {
                ATLog(.debug, "Seek operation finished.")
                self.notifyDelegatesOfPlaybackFor(chapter: self.chapterAtCurrentCursor)
            } else {
                ATLog(.error, "Seek operation failed on AVPlayerItem")
            }
        }
    }

    func registerDelegate(_ delegate: PlayerDelegate)
    {
        self.delegates.add(delegate)
    }

    func removeDelegate(_ delegate: PlayerDelegate)
    {
        self.delegates.remove(delegate)
    }

    private var chapterAtCurrentCursor: ChapterLocation
    {
        return self.cursor.currentElement.chapter
    }

    /// The overall readiness of an AVPlayer and the currently queued AVPlayerItem's readiness values.
    /// You cannot play audio without both being "ready."
    fileprivate func overallPlayerReadiness(player: AVPlayer.Status, item: AVPlayerItem.Status?) -> AVPlayerItem.Status
    {
        let avPlayerStatus = AVPlayerItem.Status(rawValue: self.avQueuePlayer.status.rawValue) ?? .unknown
        let playerItemStatus = self.avQueuePlayer.currentItem?.status ?? .unknown
        if avPlayerStatus == playerItemStatus {
            ATLog(.debug, "overallPlayerReadiness::avPlayerStatus \(avPlayerStatus.description)")
            return avPlayerStatus
        } else {
            ATLog(.debug, "overallPlayerReadiness::playerItemStatus \(playerItemStatus.description)")
            return playerItemStatus
        }
    }

    /// This should only be set by the AVPlayer via KVO.
    private var playerIsReady: AVPlayerItem.Status = .unknown {
        didSet {
            switch playerIsReady {
            case .readyToPlay:
                // Perform any queued operations like play(), and then seek().
                if let cursor = self.cursorQueuedToPlay {
                    self.cursorQueuedToPlay = nil
                    self.buildNewPlayerQueue(atCursor: cursor) { success in
                        if success {
                            self.seekWithinCurrentItem(newOffset: self.chapterAtCurrentCursor.playheadOffset)
                            self.play()
                        } else {
                            ATLog(.error, "User attempted to play when the player wasn't ready.")
                            let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.playerNotReady.rawValue, userInfo: nil)
                            self.notifyDelegatesOfPlaybackFailureFor(chapter: self.chapterAtCurrentCursor, error)
                        }
                    }
                }
                if let seekOffset = self.queuedSeekOffset {
                    self.queuedSeekOffset = nil
                    self.seekWithinCurrentItem(newOffset: seekOffset)
                }
            case .failed:
                fallthrough
            case .unknown:
                fallthrough
            @unknown default:
                break
            }
        }
    }

    private let avQueuePlayer: AVQueuePlayer
    private let audiobookID: String
    private var cursor: Cursor<SpineElement>
    private var queuedSeekOffset: TimeInterval?
    private var cursorQueuedToPlay: Cursor<SpineElement>?
    private var playerContext = 0

    var delegates: NSHashTable<PlayerDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])

    required init(cursor: Cursor<SpineElement>, audiobookID: String, drmOk: Bool) {

        self.cursor = cursor
        self.audiobookID = audiobookID
        self.isDrmOk = drmOk // Skips didSet observer
        self.avQueuePlayer = AVQueuePlayer()

        super.init()

        self.buildNewPlayerQueue(atCursor: self.cursor) { _ in }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])

        self.addPlayerObservers()
    }

    deinit {
        self.removePlayerObservers()
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }

    private func buildNewPlayerQueue(atCursor cursor: Cursor<SpineElement>, completion: (Bool)->())
    {
        let items = self.buildPlayerItems(fromCursor: cursor)
        if items.isEmpty {
            completion(false)
        } else {
            for item in self.avQueuePlayer.items() {
                NotificationCenter.default.removeObserver(self,
                                                          name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                          object: item)
            }
            self.avQueuePlayer.removeAllItems()
            for item in items {
                if self.avQueuePlayer.canInsert(item, after: nil) {
                    NotificationCenter.default.addObserver(self,
                                                           selector:#selector(currentPlayerItemEnded(item:)),
                                                           name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                           object: item)
                    self.avQueuePlayer.insert(item, after: nil)
                } else {
                    var errorMessage = "Cannot insert item: \(item). Discrepancy between AVPlayerItems and what could be inserted. "
                    if self.avQueuePlayer.items().count >= 1 {
                        errorMessage = errorMessage + "Returning as Success with a partially complete queue."
                        completion(true)
                    } else {
                        errorMessage = errorMessage + "No items were queued. Returning as Failure."
                        completion(false)
                    }
                    ATLog(.error, errorMessage)
                    return
                }
            }
            completion(true)
        }
    }

    /// Queue all valid AVPlayerItems from the cursor up to any spine element that's missing it.
    private func buildPlayerItems(fromCursor cursor: Cursor<SpineElement>?) -> [AVPlayerItem]
    {
        var items = [AVPlayerItem]()
        var cursor = cursor

        while (cursor != nil) {
            guard let fileStatus = assetFileStatus(cursor!.currentElement.downloadTask) else {
                cursor = nil
                continue
            }
            switch fileStatus {
            case .saved(let assetURL):
                let playerItem = AVPlayerItem(url: assetURL)
                playerItem.audioTimePitchAlgorithm = .timeDomain
                items.append(playerItem)
            case .missing(_):
                fallthrough
            case .unknown:
                cursor = nil
                continue
            }
            cursor = cursor?.next()
        }
        return items
    }

    /// Update the cursor if the next item in the queue is about to be put on.
    /// Not needed for explicit seek operations. Check the player for any more
    /// AVPlayerItems so that we can potentially rebuild the queue if more
    /// downloads have completed since the queue was last built.
    @objc func currentPlayerItemEnded(item: AVPlayerItem)
    {
        DispatchQueue.main.async {
            let currentCursor = self.cursor
            if let nextCursor = self.cursor.next() {
                ATLog(.debug, "Attempting to recover the missing AVPlayerItem.")
                self.cursor = nextCursor
                if self.avQueuePlayer.items().count <= 1 {
                    self.pause()
                    self.attemptToRecoverMissingPlayerItem(cursor: currentCursor)
                }
            } else {
                ATLog(.debug, "End of book reached.")
                self.pause()
            }
            self.notifyDelegatesOfPlaybackEndFor(chapter: currentCursor.currentElement.chapter)
        }
    }

    /// Try and recover from a Cursor missing its player asset.
    func attemptToRecoverMissingPlayerItem(cursor: Cursor<SpineElement>)
    {
        if let fileStatus = assetFileStatus(self.cursor.currentElement.downloadTask) {
            switch fileStatus {
            case .saved(_):
                self.rebuildQueueImmediatelyAndPlay(cursor: cursor)
            case .missing(_):
                self.rebuildOnFinishedDownload(task: self.cursor.currentElement.downloadTask)
            case .unknown:
                let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.playerNotReady.rawValue, userInfo: nil)
                self.notifyDelegatesOfPlaybackFailureFor(chapter: self.chapterAtCurrentCursor, error)
            }
        } else {
            let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.unknown.rawValue, userInfo: nil)
            self.notifyDelegatesOfPlaybackFailureFor(chapter: self.chapterAtCurrentCursor, error)
        }
    }

    func rebuildQueueImmediatelyAndPlay(cursor: Cursor<SpineElement>)
    {
        buildNewPlayerQueue(atCursor: self.cursor) { (success) in
            if success {
                self.play()
            } else {
                ATLog(.error, "Ready status is \"failed\".")
                let error = NSError(domain: errorDomain, code: OpenAccessPlayerError.unknown.rawValue, userInfo: nil)
                self.notifyDelegatesOfPlaybackFailureFor(chapter: self.chapterAtCurrentCursor, error)
            }
        }
    }

    fileprivate func rebuildOnFinishedDownload(task: DownloadTask)
    {
        ATLog(.debug, "Added observer for missing download task.")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.downloadTaskFinished),
                                               name: taskCompleteNotification,
                                               object: task)
    }

    @objc func downloadTaskFinished()
    {
        self.rebuildQueueImmediatelyAndPlay(cursor: self.cursor)
        NotificationCenter.default.removeObserver(self, name: taskCompleteNotification, object: nil)
    }
    
    func assetFileStatus(_ task: DownloadTask) -> AssetResult? {
        guard let task = task as? OpenAccessDownloadTask else {
            return nil
        }
        return task.assetFileStatus()
    }
}

/// Key-Value Observing on AVPlayer properties and items
extension OpenAccessPlayer{
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?)
    {
        guard context == &playerContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        func updatePlayback(player: AVPlayer, item: AVPlayerItem?) {
            ATLog(.debug, "updatePlayback, playerStatus: \(player.status.description) item: \(item?.status.description ?? "")")
            DispatchQueue.main.async {
                self.playerIsReady = self.overallPlayerReadiness(player: player.status, item: item?.status)
            }
        }

        func avPlayer(isPlaying: Bool) {
            DispatchQueue.main.async {
                if self.avQueuePlayerIsPlaying != isPlaying {
                    self.avQueuePlayerIsPlaying = isPlaying
                }
            }
        }

        if keyPath == #keyPath(AVQueuePlayer.status) {
            let status: AVQueuePlayer.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVQueuePlayer.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            switch status {
            case .readyToPlay:
                ATLog(.debug, "AVQueuePlayer status: ready to play.")
            case .failed:
                let error = (object as? AVQueuePlayer)?.error.debugDescription ?? "error: nil"
                ATLog(.error, "AVQueuePlayer status: failed. Error:\n\(error)")
            case .unknown:
                fallthrough
            @unknown default:
                ATLog(.debug, "AVQueuePlayer status: unknown.")
            }

            if let player = object as? AVPlayer {
                updatePlayback(player: player, item: player.currentItem)
            }
        }
        else if keyPath == #keyPath(AVQueuePlayer.rate) {
            if let newRate = change?[.newKey] as? Float,
                let oldRate = change?[.oldKey] as? Float,
                let player = (object as? AVQueuePlayer) {
                if (player.error == nil) {
                    if (oldRate == 0.0) && (newRate != 0.0) {
                        avPlayer(isPlaying: true)
                    } else if (oldRate != 0.0) && (newRate == 0.0) {
                        avPlayer(isPlaying: false)
                    }
                    return
                } else {
                    ATLog(.error, "AVPlayer error: \n\(player.error.debugDescription)")
                }
            }
            avPlayer(isPlaying: false)
            ATLog(.error, "KVO Observing did not deserialize correctly.")
        }
        else if keyPath == #keyPath(AVQueuePlayer.currentItem.status) {
            let oldStatus: AVPlayerItem.Status
            let newStatus: AVPlayerItem.Status
            if let oldStatusNumber = change?[.oldKey] as? NSNumber,
            let newStatusNumber = change?[.newKey] as? NSNumber {
                oldStatus = AVPlayerItem.Status(rawValue: oldStatusNumber.intValue)!
                newStatus = AVPlayerItem.Status(rawValue: newStatusNumber.intValue)!
            } else {
                oldStatus = .unknown
                newStatus = .unknown
            }

            if let player = object as? AVPlayer,
                oldStatus != newStatus {
                updatePlayback(player: player, item: player.currentItem)
            }
        }
        else if keyPath == #keyPath(AVQueuePlayer.reasonForWaitingToPlay) {
            if let reason = change?[.newKey] as? AVQueuePlayer.WaitingReason {
                ATLog(.debug, "Reason for waiting to play: \(reason)")
            }
        }
    }

    fileprivate func notifyDelegatesOfPlaybackFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didBeginPlaybackOf: chapter)
        }
    }

    fileprivate func notifyDelegatesOfPauseFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didStopPlaybackOf: chapter)
        }
    }

    fileprivate func notifyDelegatesOfPlaybackFailureFor(chapter: ChapterLocation, _ error: NSError?) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didFailPlaybackOf: chapter, withError: error)
        }
    }

    fileprivate func notifyDelegatesOfPlaybackEndFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didComplete: chapter)
        }
    }

    fileprivate func notifyDelegatesOfUnloadRequest() {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.playerDidUnload(self)
        }
    }

    fileprivate func addPlayerObservers() {
        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.status),
                                       options: [.old, .new],
                                       context: &playerContext)

        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.rate),
                                       options: [.old, .new],
                                       context: &playerContext)

        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.currentItem.status),
                                       options: [.old, .new],
                                       context: &playerContext)
        
        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.reasonForWaitingToPlay),
                                       options: [.old, .new],
                                       context: &playerContext)
    }

    fileprivate func removePlayerObservers() {
        self.avQueuePlayer.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.status))
        self.avQueuePlayer.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.rate))
        self.avQueuePlayer.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.currentItem.status))
        self.avQueuePlayer.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.reasonForWaitingToPlay))
    }
}
