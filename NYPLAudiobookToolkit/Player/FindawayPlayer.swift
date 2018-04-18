//
//  FindawayPlayer.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

typealias FindawayPlayheadManipulation = (previous: ChapterLocation?, destination:ChapterLocation)
final class FindawayPlayer: NSObject, Player {
    public var currentChapterLocation: ChapterLocation? {
        let chapter: ChapterLocation?
        if !self.isPlaying && self.queuedPlayheadManipulation != nil {
            chapter = self.queuedPlayheadManipulation?.destination
        } else {
            chapter = ChapterLocation(
                number: self.chapterAtCursor.number,
                part: self.chapterAtCursor.part,
                duration: self.chapterAtCursor.duration,
                startOffset: 0,
                playheadOffset: TimeInterval(self.currentOffset),
                title: self.chapterAtCursor.title,
                audiobookID: self.audiobookID
            )
        }
        return chapter
    }

    var delegates: NSHashTable<PlayerDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])
    private var readyForPlayback: Bool = false
    private var resumePlaybackLocation: ChapterLocation?

    // `queuedPlayheadManipulation` is for a manipulation that has been
    // made to the cursor but has not been passed onto the AudioEngine.playbackEngine yet.
    //
    // The main reason we use this is to allow us to perform playhead manipulations
    // without actually initiating playback. This is useful for state restoration.
    private var queuedPlayheadManipulation: FindawayPlayheadManipulation?

    // `queuedLocationWaitingForPlayback` is for the location that has been
    // requested for playback but for some reason is not able to be played
    // at this moment.
    //
    // The two main reasons to queue a chapter instead of playing it
    // immediately are that the AudioEngine SDK is still initializing
    // so playback can't be started or you want to load a new chapter
    // which is an expensive operation.
    private var queuedLocationWaitingForPlayback: ChapterLocation?

    private var willBeReadyToPlayNewChapterAt: Date = Date()
    private var debounceBufferTime: TimeInterval = 0.2

    private var sessionKey: String {
        return self.spineElement.sessionKey
    }

    private var licenseID: String {
        return self.spineElement.licenseID
    }

    private var audiobookID: String {
        return self.spineElement.audiobookID
    }

    /// If no book is loaded, AudioEngine returns 0, so this is consistent with their behavior
    private var currentOffset: UInt {
        return FAEAudioEngine.shared()?.playbackEngine?.currentOffset ?? 0
    }
    
    private var chapterAtCursor: ChapterLocation {
        return self.cursor.currentElement.chapter
    }

    var isPlaying: Bool {
        return FAEAudioEngine.shared()?.playbackEngine?.playerStatus == FAEPlayerStatus.playing
    }

    private var bookIsLoaded: Bool {
        let chapter = FAEAudioEngine.shared()?.playbackEngine?.currentLoadedChapter()
        guard let loadedAudiobookID = chapter?.audiobookID else { return false }
        return loadedAudiobookID == self.audiobookID
    }

    private var cursor: Cursor<SpineElement>
    private let spineElement: FindawaySpineElement
    private var eventHandler: FindawayPlaybackNotificationHandler
    private var queue = DispatchQueue(label: "org.nypl.labs.NYPLAudiobookToolkit.FindawayPlayer")
    public init(spineElement: FindawaySpineElement, eventHandler: FindawayPlaybackNotificationHandler, lifeCycleManager: AudiobookLifeCycleManager, cursor: Cursor<SpineElement>) {
        self.eventHandler = eventHandler
        self.spineElement = spineElement
        self.cursor = cursor
        self.readyForPlayback = lifeCycleManager.audioEngineDatabaseHasBeenVerified
        super.init()
        self.eventHandler.delegate = self
        lifeCycleManager.registerDelegate(self)
    }

    convenience init(spineElement: FindawaySpineElement, cursor: Cursor<SpineElement>) {
        self.init(spineElement: spineElement, eventHandler: DefaultFindawayPlaybackNotificationHandler(), lifeCycleManager: DefaultAudiobookLifecycleManager.shared, cursor: cursor)
    }
    
    public func registerDelegate(_ delegate: PlayerDelegate) {
        self.delegates.add(delegate)
    }
    
    public func removeDelegate(_ delegate: PlayerDelegate) {
        self.delegates.remove(delegate)
    }
    
    var playbackRate: PlaybackRate {
        get {
            let rawValue = FAEAudioEngine.shared()?.playbackEngine?.currentRate
            if let value = rawValue {
                return PlaybackRate(rawValue: Int(value * 100))!
            } else {
                return .normalTime
            }
        }

        set(newRate) {
            self.queue.sync {
                FAEAudioEngine.shared()?.playbackEngine?.currentRate = PlaybackRate.convert(rate: newRate)
            }
        }
    }

    func skipForward() {
        self.queue.async { [weak self] in
            self?.performSkip(15)
        }
    }

    func skipBack() {
        self.queue.async { [weak self] in
            self?.performSkip(-15)
        }
    }

    func play() {
        self.queue.async { [weak self] in
            self?.performPlay()
        }
    }

    func pause() {
        self.queue.async { [weak self] in
            self?.performPause()
        }
    }
    
    func playAtLocation(_ location: ChapterLocation) {
        self.queue.async { [weak self] in
            self?.performJumpToLocation(location)
        }
    }
    
    func movePlayheadToLocation(_ location: ChapterLocation) {
        self.queue.async { [weak self] in
            self?.queuedPlayheadManipulation = self?.updateCursorAndRequestPlaybackFor(location)
        }
    }

    private func performSkip(_ time: Int) {
        let newTime = Int(self.currentOffset) + time
        let location = self.currentChapterLocation?.chapterWith(TimeInterval(newTime))
        if let location = location {
            self.performJumpToLocation(location)
        }
    }
    
    private func performPlay() {
        if let resumeLocation = self.resumePlaybackLocation {
            self.performJumpToLocation(resumeLocation)
        } else {
            if let manipulation = self.queuedPlayheadManipulation {
                self.movePlayhead(from: manipulation.previous, to: manipulation.destination)
            } else if let location = self.currentChapterLocation?.chapterWith(0) {
                self.performJumpToLocation(location)
            }
        }
    }
    
    private func performPause() {
        if self.isPlaying {
            self.resumePlaybackLocation = self.currentChapterLocation
            FAEAudioEngine.shared()?.playbackEngine?.pause()
        } else {
            FAEAudioEngine.shared()?.playbackEngine?.unload()
        }
    }
    
    private func performJumpToLocation(_ location: ChapterLocation) {
        if self.readyForPlayback {
            self.queuedPlayheadManipulation = self.updateCursorAndRequestPlaybackFor(location)
            if let manipulation = self.queuedPlayheadManipulation {
                self.movePlayhead(from: manipulation.previous, to: manipulation.destination)
            }
        } else {
            self.queuedLocationWaitingForPlayback = location
        }
    }
    
    private func updateCursorAndRequestPlaybackFor(_ location: ChapterLocation) -> FindawayPlayheadManipulation? {
        func attemptToMoveCursorForwardTo(location: ChapterLocation) -> ChapterLocation? {
            // Only if the time points into the next chapter should we try to move the cursor forward.
            guard let timeIntoNextChapter = location.timeIntoNextChapter else { return nil }
            var possibleDestinationLocation: ChapterLocation?
            // Attempt to move the cursor forward indicating
            // there is a next chapter for us to play.
            if let newCursor = self.cursor.next() {
                self.cursor = newCursor
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(
                    timeIntoNextChapter
                )
            } else {
                // If there is no next chapter, then we are at the end of the book
                // and we skip to the end.
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(
                    self.chapterAtCursor.duration
                )
            }
            return possibleDestinationLocation
        }
        
        func attemptToMoveCursorBackTo(location: ChapterLocation) -> ChapterLocation? {
            // Only if the time points into the last chapter should we try to move the cursor back.
            guard let timeIntoPreviousChapter = location.secondsBeforeStart else { return nil }
            var possibleDestinationLocation: ChapterLocation?
            // Attempt to move the cursor backwards indicating
            // there is a previous chapter for us to play.
            if let newCursor = self.cursor.prev() {
                self.cursor = newCursor
                let durationOfChapter =  self.chapterAtCursor.duration
                let playheadOffset = durationOfChapter - timeIntoPreviousChapter
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(max(0, playheadOffset))
            } else {
                // If there is no previous chapter, we are at the start of the book
                // and skip to the beginning.
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(0)
            }
            return possibleDestinationLocation
        }

        var possibleDestinationLocation: ChapterLocation? = location
        let locationBeforeNavigation = self.currentChapterLocation

        // Check to see if our playback location is in the next chapter
        if let nextChapter = attemptToMoveCursorForwardTo(location: location) {
            possibleDestinationLocation = nextChapter
        // Check if playback location is in the previous chapter
        } else if let previousChapter = attemptToMoveCursorBackTo(location: location) {
            possibleDestinationLocation = previousChapter
        }
        
        guard let destinationLocation = possibleDestinationLocation else { return nil }
        return (previous: locationBeforeNavigation, destination: destinationLocation)
    }

    /// Method to determine which AudioEngine SDK should be called
    /// to move the playhead or resume playback.
    ///
    /// Not all playhead movement costs the same. In order to ensure snappy and consistent
    /// behavior from FAEPlaybackEngine, we must be careful about how many calls we make to
    /// `[FAEPlaybackEngine playForAudiobookID:partNumber:chapterNumber:offset:sessionKey:licenseID]`.
    /// Meanwhile, calls to `[FAEPlaybackEngine setCurrentOffset]` are cheap and can be made repeatedly.
    /// Because of this we must determine what kind of request we have received before proceeding.
    ///
    /// If moving the playhead stays in the same file, then the update is instant and we are still
    /// ready to get a new request.
    private func movePlayhead(from locationBeforeNavigation: ChapterLocation?, to destinationLocation: ChapterLocation) {
        func isResumeDescription(_ chapter: ChapterLocation) -> Bool {
            guard let resumeDescription = self.resumePlaybackLocation else {
                return false
            }
            return resumeDescription === chapter
        }

        func seekOperation(locationBeforeNavigation: ChapterLocation?, destinationLocation: ChapterLocation) -> Bool {
            return self.bookIsLoaded && self.locationsPointToTheSameChapter(lhs: destinationLocation, rhs: locationBeforeNavigation)
        }
        
        /// We queue the playhead move in order to rate limit the expensive
        /// move operation.
        func queueChapterManipulation() {
            func attemptQueuedPlayheadManipulation() {
                guard let destinationLocation = self.queuedLocationWaitingForPlayback else {
                    return
                }
                if Date() < self.willBeReadyToPlayNewChapterAt {
                    queueChapterManipulation()
                } else {
                    self.loadAndRequestPlayback(destinationLocation)
                    self.queuedLocationWaitingForPlayback = nil
                }
            }
            
            self.queue.asyncAfter(deadline: self.dispatchDeadline()) {
                attemptQueuedPlayheadManipulation()
            }
        }

        let isSeekOperation = seekOperation(
            locationBeforeNavigation: locationBeforeNavigation,
            destinationLocation: destinationLocation
        )
    
        // Resuming playback from the last point is practically free. We get notifications
        // when it succeeds so we do not have to update the delegates.
        if isResumeDescription(destinationLocation) {
            FAEAudioEngine.shared()?.playbackEngine?.resume()
        } else if isSeekOperation {
            // Seek operations are very cheap and move the playhead almost instantly.
            // They can be performed repeatedly within a chapter without fail.
            FAEAudioEngine.shared()?.playbackEngine?.currentOffset = UInt(destinationLocation.playheadOffset)
            DispatchQueue.main.async { [weak self] in
                self?.notifyDelegatesOfPlaybackFor(chapter: destinationLocation)
            }
        } else {
            // This is the expensive path, so instead of making the request immediately
            // we queue it and trash the existing request if a new one comes in.
            self.willBeReadyToPlayNewChapterAt = Date().addingTimeInterval(self.debounceBufferTime)
            self.queuedLocationWaitingForPlayback = destinationLocation
            queueChapterManipulation()
        }
        self.queuedPlayheadManipulation = nil
    }

    private func loadAndRequestPlayback(_ location: ChapterLocation) {
        FAEAudioEngine.shared()?.playbackEngine?.play(
            forAudiobookID: self.audiobookID,
            partNumber: location.part,
            chapterNumber: location.number,
            offset: UInt(location.playheadOffset),
            sessionKey: self.sessionKey,
            licenseID: self.licenseID
        )
    }

    private func locationsPointToTheSameChapter(lhs: ChapterLocation?, rhs: ChapterLocation?) -> Bool {
        return lhs?.inSameChapter(other: rhs) ?? false
    }

    private func currentChapterIsAt(part: UInt, number: UInt, audiobookID: String) -> Bool {
        guard let chapter = self.currentChapterLocation else { return false }
        return chapter.audiobookID == audiobookID &&
            chapter.part == part &&
            chapter.number == number
    }

    private func dispatchDeadline() -> DispatchTime {
        return DispatchTime.now() + self.debounceBufferTime
    }

    private func notifyDelegatesOfPlaybackFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didBeginPlaybackOf: chapter)
        }
    }

    private func notifyDelegatesOfPauseFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didStopPlaybackOf: chapter)
        }
    }

    private func notifyDelegatesOfPlaybackEndFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didComplete: chapter)
        }
    }
}

extension FindawayPlayer: AudiobookLifecycleManagerDelegate {
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifeCycleManager) {
        func handleLifecycleManagerUpdate(hasBeenVerified: Bool) {
            self.readyForPlayback = hasBeenVerified
            if let location = self.queuedLocationWaitingForPlayback {
                self.playAtLocation(location)
            }
        }

        self.queue.async {
            handleLifecycleManagerUpdate(hasBeenVerified: audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified)
        }
    }
}

extension FindawayPlayer: FindawayPlaybackNotificationHandlerDelegate {
    func audioEnginePlaybackFinished(_ notificationHandler: FindawayPlaybackNotificationHandler, for chapter: FAEChapterDescription) {
        let chapterLocation = self.cursor.data.first { (spineElement) -> Bool in
            spineElement.chapter.number == chapter.chapterNumber && spineElement.chapter.part == chapter.partNumber
        }?.chapter
        guard let duration = chapterLocation?.duration else {
            return
        }
        guard let chapterAtEnd = chapterLocation?.chapterWith(duration) else {
            return
        }

        self.notifyDelegatesOfPlaybackEndFor(chapter: chapterAtEnd)
    }

    func audioEnginePlaybackStarted(_ notificationHandler: FindawayPlaybackNotificationHandler, for findawayChapter: FAEChapterDescription) {
        func handlePlaybackStartedFor(findawayChapter: FAEChapterDescription) {
            if !self.currentChapterIsAt(part: findawayChapter.partNumber, number: findawayChapter.chapterNumber, audiobookID: findawayChapter.audiobookID) {
                let cursorPredicate = { (spineElement: SpineElement) -> Bool in
                    return spineElement.chapter.number == findawayChapter.chapterNumber && spineElement.chapter.part == findawayChapter.partNumber
                }
                if let newCursor = self.cursor.cursor(at: cursorPredicate) {
                    self.cursor = newCursor
                }
            }

            if let chapter = self.currentChapterLocation {
                DispatchQueue.main.async { [weak self] () -> Void in
                    self?.notifyDelegatesOfPlaybackFor(chapter: chapter)
                }
            }
        }

        self.queue.async {
            handlePlaybackStartedFor(findawayChapter: findawayChapter)
        }
    }

    func audioEnginePlaybackPaused(_ notificationHandler: FindawayPlaybackNotificationHandler, for findawayChapter: FAEChapterDescription) {
        if self.currentChapterIsAt(part: findawayChapter.partNumber, number: findawayChapter.chapterNumber, audiobookID: findawayChapter.audiobookID) {
            if let currentChapter = self.currentChapterLocation {
                DispatchQueue.main.async { [weak self] () -> Void in
                    self?.notifyDelegatesOfPauseFor(chapter: currentChapter)
                }
            }
        }
    }
}
