import AVFoundation

final class OpenAccessPlayer: NSObject, Player {

    var isPlaying: Bool {
        return self.avQueuePlayerIsPlaying
    }

    private var avQueuePlayerIsPlaying: Bool = false {
        didSet {
            if let location = self.currentChapterLocation {
                if avQueuePlayerIsPlaying {
                    self.notifyDelegatesOfPlaybackFor(chapter: location)
                } else {
                    self.notifyDelegatesOfPauseFor(chapter: location)
                    //godo todo need further work to determine where "playback end" should go
                    //self.notifyDelegatesOfPlaybackEndFor(chapter: location)
                }
            }
        }
    }
    
    var playbackRate: PlaybackRate = .normalTime {
        didSet {
            if self.avQueuePlayer.rate != 0.0 {
                let rate = PlaybackRate.convert(rate: self.playbackRate)
                //GODO todo listen on KVO for any errors related to changing this
                self.avQueuePlayer.rate = rate
            } else {
                self.queuedPlaybackRate = self.playbackRate
            }
        }
    }

    /// The user may set the playback rate independently of actually playing the
    /// audio. The player should queue the new rate if the current rate is 0
    /// (paused).
    private var queuedPlaybackRate: PlaybackRate?
    
    var currentChapterLocation: ChapterLocation? {
        return ChapterLocation(
            number: self.chapterAtCursor.number,
            part: self.chapterAtCursor.part,
            duration: self.chapterAtCursor.duration,
            startOffset: 0,
            playheadOffset: self.avQueuePlayer.currentTime().seconds,     //godo todo wip
            title: self.chapterAtCursor.title,
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
            ATLog(.error, "User attempted to play when the player wasn't ready.")
            //godo todo consider doing some kind of queueing here similar to how findawayplayer handles it
        }
    }

    func pause() {
        self.avQueuePlayer.pause()
    }

    func unload() {
        //godo todo see if there's any need for unload() on AVPlayer
        self.isLoaded = false
    }

    func skipPlayhead(_ timeInterval: TimeInterval, completion: ((ChapterLocation)->())? = nil) -> () {
        guard let currentLocation = self.currentChapterLocation else {
            ATLog(.error, "Invalid chapter information required for skip.")
            return
        }
        let currentPlayheadOffset = currentLocation.playheadOffset
        let chapterDuration = currentLocation.duration
        let adjustedSkip = adjustedSkipInterval(currentPlayheadOffset: currentPlayheadOffset,
                                                currentChapterDuration: chapterDuration,
                                                requestedSkipDuration: timeInterval)

        if let destinationLocation = currentLocation.chapterWith(adjustedSkip) {
            self.playAtLocation(destinationLocation)
            completion?(destinationLocation)
        } else {
            ATLog(.error, "New chapter location could not be created from skip.")
            //todo godo I don't thnk there should be an error to the view controller here...
            return
        }
    }
    
    func playAtLocation(_ chapter: ChapterLocation) {

        let offset = chapter.playheadOffset

        if chapter.inSameChapter(other: self.chapterAtCursor) {
            self.seek(offset: offset)
        }
        else {

            let possibleNewCursor = self.cursor.cursor { spineElement -> Bool in
                return chapter.inSameChapter(other: spineElement.chapter)
            }

            guard let newCursor = possibleNewCursor else {
                //godo todo create an nserror to give a specific message here
                //also update the player vc to forward those messages to the user
                self.notifyDelegatesOfPlaybackFailureFor(chapter: chapter, nil)
                return
            }

            guard let fileStatus = (newCursor.currentElement.downloadTask as? OpenAccessDownloadTask)?.assetFileStatus() else {
                //critical error;
                notifyDelegatesOfPlaybackFailureFor(chapter: chapter, nil)
                return
            }

            switch fileStatus {
            case .saved(_):
                if newCursor.index < self.avQueuePlayer.items().count {
                    self.buildNewPlayerQueue(atCursor: newCursor) { (success) in
                        if success {
                            self.play()
                        } else {
                            //error
                        }
                    }
                } else {
                    //godo todo should be unreachable code...
                    return
                }
            case .missing(_):
                //godo todo error or message just to say that the chapter selected has not been downloaded
                return
            case .unknown:
                self.notifyDelegatesOfPlaybackFailureFor(chapter: chapter, nil)
                return
            }
        }
    }

    func movePlayheadToLocation(_ location: ChapterLocation) {
        //godo todo anything else needed here?
        self.playAtLocation(location)
    }

    /// Moving within the current AVPlayerItem.
    private func seek(offset: TimeInterval) {
        guard let currentItem = self.avQueuePlayer.currentItem else {
            ATLog(.error, "No current AVPlayerItem in AVQueuePlayer")
            return
        }
        currentItem.seek(to: CMTimeMakeWithSeconds(Float64(offset), preferredTimescale: Int32(1))) { finished in
            if !finished {
                ATLog(.error, "Seek operation failed on AVPlayerItem")
            } else {
                ATLog(.debug, "Seek operation finished.")
                self.notifyDelegatesOfPlaybackFor(chapter: self.cursor.currentElement.chapter)
            }
        }
    }

    func registerDelegate(_ delegate: PlayerDelegate) {
        self.delegates.add(delegate)
    }

    func removeDelegate(_ delegate: PlayerDelegate) {
        self.delegates.remove(delegate)
    }

    private var chapterAtCursor: ChapterLocation {
        return self.cursor.currentElement.chapter
    }

    private let audiobookID: String
    private var cursor: Cursor<OpenAccessSpineElement>
    private let avQueuePlayer: AVQueuePlayer
    private var readyForPlayback: Bool = false
    private var openAccessPlayerContext = 0

    var delegates: NSHashTable<PlayerDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])

    required init(cursor: Cursor<OpenAccessSpineElement>, audiobookID: String) {

        self.cursor = cursor
        self.audiobookID = audiobookID
        self.avQueuePlayer = AVQueuePlayer()

        super.init()

        self.buildNewPlayerQueue(atCursor: self.cursor) { (success) in
            if !success {
                ATLog(.error, "Could not create a queue for the AVPlayer on init.")
            }
        }

        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.status),
                                       options: [.old, .new],
                                       context: &openAccessPlayerContext)

        self.avQueuePlayer.addObserver(self,
                                       forKeyPath: #keyPath(AVQueuePlayer.rate),
                                       options: [.old, .new],
                                       context: &openAccessPlayerContext)

    }

    private func buildNewPlayerQueue(atCursor cursor: Cursor<OpenAccessSpineElement>, completion: (Bool)->()) {
        let items = self.buildPlayerItems(cursor: cursor)
        if !items.isEmpty {
            self.avQueuePlayer.removeAllItems()
            for item in items {
                if self.avQueuePlayer.canInsert(item, after: nil) {
                    self.avQueuePlayer.insert(item, after: nil)
                } else {
                    completion(false)
                    return
                }
            }
            self.cursor = cursor
            completion(true)
        } else {
            completion(false)
        }
    }

    private func buildPlayerItems(cursor: Cursor<OpenAccessSpineElement>?) -> [AVPlayerItem] {

        var items = [AVPlayerItem]()
        var cursor = cursor

        // Queue items that are ready to play.
        while (cursor != nil) {
            if let downloadTask = cursor!.currentElement.downloadTask as? OpenAccessDownloadTask {
                switch downloadTask.assetFileStatus() {
                case .saved(let assetURL):
                    let playerItem = AVPlayerItem(url: assetURL)
                    playerItem.audioTimePitchAlgorithm = .timeDomain
                    items.append(playerItem)
                case .missing(_):
                    //godo todo download missing error
                    fallthrough
                case .unknown:
                    //godo todo send error
                    break
                }
            }
            cursor = cursor?.next()
        }
        return items
    }
}

/// Key-Value Observing on AVPlayer properties
extension OpenAccessPlayer {
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {

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
                self.readyForPlayback = true
            case .failed:
                let error = (object as? AVQueuePlayer)?.error.debugDescription ?? "error: nil"
                ATLog(.error, "AVQueuePlayer status: failed to get ready for playback. Error:\n\(error)")
            case .unknown:
                ATLog(.debug, "AVQueuePlayer status: unknown.")
            }
        }
        else if keyPath == #keyPath(AVQueuePlayer.rate) {
            // godo todo wip
            if let newRate = change?[.newKey] as? Float,
                let oldRate = change?[.oldKey] as? Float,
                let player = (object as? AVQueuePlayer) {
                if (player.error == nil) {
                    if (oldRate == 0.0) && (newRate != 0.0) {
                        self.avQueuePlayerIsPlaying = true
                    } else if (oldRate != 0.0) && (newRate == 0.0) {
                        self.avQueuePlayerIsPlaying = false
                    }
                    return
                }
            }
            self.avQueuePlayerIsPlaying = false
            ATLog(.error, "")
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
