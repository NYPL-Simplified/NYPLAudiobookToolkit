import AVFoundation

final class OpenAccessPlayer: NSObject, Player {

    var isPlaying: Bool {
        return self.avQueuePlayerIsPlaying
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

    /// Note: Changing the rate of the AVPlayer to a nonzero value will
    /// immediately play audio. Therefore, the player should queue the new rate
    /// if the current rate is 0 (paused).
    private var queuedPlaybackRate: PlaybackRate?
    var playbackRate: PlaybackRate = .normalTime {
        didSet {
            if self.avQueuePlayer.rate != 0.0 {
                let rate = PlaybackRate.convert(rate: self.playbackRate)
                self.avQueuePlayer.rate = rate
            } else {
                self.queuedPlaybackRate = self.playbackRate
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

    func play() {
        if self.readyForPlayback {
            self.avQueuePlayer.play()
            if let queuedRate = self.queuedPlaybackRate {
                let rate = PlaybackRate.convert(rate: queuedRate)
                self.avQueuePlayer.rate = rate
                self.queuedPlaybackRate = nil
            }
        } else {
            // Should be unreachable...
            ATLog(.error, "User attempted to play when the player wasn't ready.")
            let error = NSError(domain: OpenAccessPlayerDomain, code: 2, userInfo: nil)
            self.notifyDelegatesOfPlaybackFailureFor(chapter: self.currentChapterLocation!, error)
        }
    }

    func pause() {
        self.avQueuePlayer.pause()
    }

    func unload() {
        self.isLoaded = false
        self.avQueuePlayer.removeAllItems()
        self.notifyDelegatesOfUnloadRequest()
    }

    func skipPlayhead(_ timeInterval: TimeInterval, completion: ((ChapterLocation)->())? = nil) -> () {
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
            self.playAtLocation(destinationLocation)
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
    func playAtLocation(_ newLocation: ChapterLocation) {

        let newPlayhead = move(cursor: self.cursor, to: newLocation)

        // If we're in the same AVPlayerItem, apply seek directly to AVPlayer.
        if newPlayhead.location.inSameChapter(other: self.cursor.currentElement.chapter) {
            self.seekWithinCurrentItem(newOffset: newPlayhead.location.playheadOffset)
            return
        }
        // Otherwise, check for an AVPlayerItem at the new chapter, rebuild the player
        // queue starting from there, and then begin playing at that location.
        guard let newItemDownloadStatus = (newPlayhead.cursor.currentElement.downloadTask as? OpenAccessDownloadTask)?.assetFileStatus() else {
            let error = NSError(domain: OpenAccessPlayerDomain, code: 0, userInfo: nil)
            notifyDelegatesOfPlaybackFailureFor(chapter: newPlayhead.location, error)
            return
        }

        switch newItemDownloadStatus {
        case .saved(_):
            self.buildNewPlayerQueue(atCursor: newPlayhead.cursor) { (success) in
                if success {
                    self.cursor = newPlayhead.cursor
                    self.seekWithinCurrentItem(newOffset: newPlayhead.location.playheadOffset)
                    self.play()
                } else {
                    ATLog(.error, "Failed to create a new queue for the player. Keeping playback at the current player item.")
                    let error = NSError(domain: OpenAccessPlayerDomain, code: 0, userInfo: nil)
                    self.notifyDelegatesOfPlaybackFailureFor(chapter: newLocation, error)
                }
            }
        case .missing(_):
            // TODO: Could eventually handle streaming from here.
            let error = NSError(domain: OpenAccessPlayerDomain, code: 1, userInfo: nil)
            self.notifyDelegatesOfPlaybackFailureFor(chapter: newLocation, error)
            return
        case .unknown:
            let error = NSError(domain: OpenAccessPlayerDomain, code: 0, userInfo: nil)
            self.notifyDelegatesOfPlaybackFailureFor(chapter: newLocation, error)
            return
        }
    }

    func movePlayheadToLocation(_ location: ChapterLocation) {
        self.playAtLocation(location)
        self.pause()
    }

    /// Moving within the current AVPlayerItem.
    private func seekWithinCurrentItem(newOffset: TimeInterval) {
        guard let currentItem = self.avQueuePlayer.currentItem else {
            ATLog(.error, "No current AVPlayerItem in AVQueuePlayer")
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
                self.notifyDelegatesOfPlaybackFor(chapter: self.cursor.currentElement.chapter)
            } else {
                ATLog(.error, "Seek operation failed on AVPlayerItem")
            }
        }
    }

    func registerDelegate(_ delegate: PlayerDelegate) {
        self.delegates.add(delegate)
    }

    func removeDelegate(_ delegate: PlayerDelegate) {
        self.delegates.remove(delegate)
    }

    private var chapterAtCurrentCursor: ChapterLocation {
        return self.cursor.currentElement.chapter
    }

    private var readyForPlayback: Bool = false {
        didSet {
            // Perform queued operations on AVPlayer if needed.
            if self.avQueuePlayer.status == .readyToPlay,
            self.avQueuePlayer.currentItem?.status == .readyToPlay,
            let queuedOffset = self.queuedSeekOffset {
                self.seekWithinCurrentItem(newOffset: queuedOffset)
                self.queuedSeekOffset = nil
            }
        }
    }

    private let avQueuePlayer: AVQueuePlayer
    private let audiobookID: String
    private var cursor: Cursor<SpineElement>
    private var queuedSeekOffset: TimeInterval?
    private var openAccessPlayerContext = 0

    var delegates: NSHashTable<PlayerDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])

    required init(cursor: Cursor<SpineElement>, audiobookID: String) {

        self.cursor = cursor
        self.audiobookID = audiobookID
        self.avQueuePlayer = AVQueuePlayer()

        super.init()

        self.buildNewPlayerQueue(atCursor: self.cursor) { (success) in
            if !success {
                ATLog(.error, "Could not create a queue for the AVPlayer on init.")
                let error = NSError(domain: OpenAccessPlayerDomain, code: 0, userInfo: nil)
                self.notifyDelegatesOfPlaybackFailureFor(chapter: self.cursor.currentElement.chapter, error)
            }
        }

        if #available(iOS 10.0, *) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        } else {
            // https://forums.swift.org/t/using-methods-marked-unavailable-in-swift-4-2/14949
            AVAudioSession.sharedInstance().perform(NSSelectorFromString("setCategory:error:"),
                                                    with: AVAudioSession.Category.playback)
        }
        try? AVAudioSession.sharedInstance().setActive(true, options: [])

        self.addPlayerObservers()
    }

    deinit {
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }

    private func buildNewPlayerQueue(atCursor cursor: Cursor<SpineElement>, completion: (Bool)->()) {
        let items = self.buildPlayerItems(cursor: cursor)
        if !items.isEmpty {
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
                    ATLog(.error, "Error building new queue. Discrepancy between AVPlayerItems and what could be inserted.")
                    completion(true)
                    return
                }
            }
            completion(true)
        } else {
            completion(false)
        }
    }

    private func buildPlayerItems(cursor: Cursor<SpineElement>?) -> [AVPlayerItem] {

        var items = [AVPlayerItem]()
        var cursor = cursor

        // Queue items with saved download tasks.
        while (cursor != nil) {
            if let downloadTask = cursor!.currentElement.downloadTask as? OpenAccessDownloadTask {
                switch downloadTask.assetFileStatus() {
                case .saved(let assetURL):
                    let playerItem = AVPlayerItem(url: assetURL)
                    playerItem.audioTimePitchAlgorithm = .timeDomain
                    items.append(playerItem)
                case .missing(_):
                    fallthrough
                case .unknown:
                    break
                }
            }
            cursor = cursor?.next()
        }
        return items
    }

    private func addPlayerObservers() {
        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.status),
                                       options: [.old, .new],
                                       context: &openAccessPlayerContext)

        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.rate),
                                       options: [.old, .new],
                                       context: &openAccessPlayerContext)

        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.currentItem.status),
                                       options: [.old, .new],
                                       context: &openAccessPlayerContext)
    }

    /// Update the cursor if the next item in the queue is about to be put on. Seek
    /// operations are done explicitly, so they update the cursor separately.
    @objc func currentPlayerItemEnded(item: AVPlayerItem) {
        if let nextCursor = self.cursor.next() {
            self.cursor = nextCursor
        } else {
            self.pause()
        }
        self.notifyDelegatesOfPlaybackEndFor(chapter: self.cursor.currentElement.chapter)
    }
}

/// Key-Value Observing on AVPlayer properties and items
extension OpenAccessPlayer {
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {

        func updatePlayback(status: Bool) {
            DispatchQueue.main.async {
                self.readyForPlayback = status
            }
        }

        func avPlayer(isPlaying: Bool) {
            DispatchQueue.main.async {
                self.avQueuePlayerIsPlaying = isPlaying
            }
        }

        guard context == &openAccessPlayerContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
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
                updatePlayback(status: true)
            case .failed:
                let error = (object as? AVQueuePlayer)?.error.debugDescription ?? "error: nil"
                ATLog(.error, "AVQueuePlayer status: failed to get ready for playback. Error:\n\(error)")
                updatePlayback(status: false)
            case .unknown:
                ATLog(.debug, "AVQueuePlayer status: unknown.")
                updatePlayback(status: false)
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
            ATLog(.error, "")
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
            if oldStatus != .readyToPlay && newStatus == .readyToPlay {
                updatePlayback(status: true)
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
}
