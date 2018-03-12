//
//  FindawayPlayer.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

final class FindawayPlayer: NSObject, Player {
    func chapterIsPlaying(_ location: ChapterLocation) -> Bool {
        guard self.isPlaying else { return false }
        var chapterIsPlaying = false
        self.queue.sync {
            chapterIsPlaying = self.currentChapterIsAt(part: location.part, number: location.number)
        }
        return chapterIsPlaying
    }

    private var currentChapterLocation: ChapterLocation? {
        return ChapterLocation(
            number: self.chapterAtCursor.number,
            part: self.chapterAtCursor.part,
            duration: self.chapterAtCursor.duration,
            startOffset: 0,
            playheadOffset: TimeInterval(self.currentOffset),
            title: self.chapterAtCursor.title
        )
    }

    var delegates: NSHashTable<PlayerDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])
    
    public func registerDelegate(_ delegate: PlayerDelegate) {
        self.delegates.add(delegate)
    }
    
    public func removeDelegate(_ delegate: PlayerDelegate) {
        self.delegates.remove(delegate)
    }

    private var resumePlaybackLocation: ChapterLocation?
    
    // Not all `ChapterLocation`s are played immediately on request.
    // The two main reasons to queue a chapter instead of playing it
    // immediately are that the AudioEngine SDK is still initializing
    // so playback can't be started or you want to load a new chapter
    // which is an expensive operation.
    private var queuedLocation: ChapterLocation?

    private var readyForPlayback: Bool {
        return self.audioEngineDatabaseHasBeenVerified
    }
    
    private var willBeReadyAt: Date = Date()
    private var debounceBufferTime: TimeInterval = 0.5
    private var dispatchDeadline: DispatchTime {
        return DispatchTime.now() + self.debounceBufferTime
    }

    private var audioEngineDatabaseHasBeenVerified: Bool
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

    private var currentBookIsPlaying: Bool {
        return self.isPlaying && self.bookIsLoaded
    }
    
    private var chapterAtCursor: ChapterLocation {
        return self.cursor.currentElement.chapter
    }

    private var currentFindawayChapter: FAEChapterDescription? {
        var chapter: FAEChapterDescription? = nil
        if self.isPlaying {
            // If there is no book playing the SDK will still return a loaded chapter, this chapter will have a blank audiobook ID and must not be used. Will cause undefined behavior.
            chapter = FAEAudioEngine.shared()?.playbackEngine?.currentLoadedChapter()
        }
        return chapter
    }

    var isPlaying: Bool {
        return FAEAudioEngine.shared()?.playbackEngine?.playerStatus == FAEPlayerStatus.playing
    }

    private var bookIsLoaded: Bool {
        guard let loadedAudiobookID = self.currentFindawayChapter?.audiobookID else { return false }
        return loadedAudiobookID == self.audiobookID
    }

    private var cursor: Cursor<SpineElement>
    private let spineElement: FindawaySpineElement
    private var eventHandler: FindawayPlaybackNotificationHandler
    private var queue = DispatchQueue(label: "com.nyplaudiobooktoolkit.FindawayPlayer")
    public init(spineElement: FindawaySpineElement, eventHandler: FindawayPlaybackNotificationHandler, lifeCycleManager: AudiobookLifeCycleManager, cursor: Cursor<SpineElement>) {
        self.eventHandler = eventHandler
        self.spineElement = spineElement
        self.cursor = cursor
        self.audioEngineDatabaseHasBeenVerified = lifeCycleManager.audioEngineDatabaseHasBeenVerified
        super.init()
        self.eventHandler.delegate = self
        lifeCycleManager.registerDelegate(self)
    }
    
    convenience init(spineElement: FindawaySpineElement, cursor: Cursor<SpineElement>) {
        self.init(spineElement: spineElement, eventHandler: DefaultFindawayPlaybackNotificationHandler(), lifeCycleManager: DefaultAudiobookLifecycleManager.shared, cursor: cursor)
    }

    func skipForward() {
        self.queue.async {
            let someTimeFromNow = self.currentOffset + 15
            let location = self.currentChapterLocation?.chapterWith(TimeInterval(someTimeFromNow))
            if let location = location {
                self.performJumpToLocation(location)
            }
        }
    }

    func skipBack() {
        self.queue.async {
            let someTimeAgo = Int(self.currentOffset) - 15
            let location = self.currentChapterLocation?.chapterWith(TimeInterval(someTimeAgo))
            if let location = location {
                self.performJumpToLocation(location)
            }
        }
    }

    func play() {
        self.queue.async {
            if let resumeLocation = self.resumePlaybackLocation {
                self.jumpToLocation(resumeLocation)
            } else {
                if let location = self.currentChapterLocation?.chapterWith(0) {
                    self.jumpToLocation(location)
                }
            }
        }
    }
    
    func pause() {
        self.queue.async {
            self.resumePlaybackLocation = self.currentChapterLocation
            FAEAudioEngine.shared()?.playbackEngine?.pause()
        }
    }
    
    func jumpToLocation(_ location: ChapterLocation) {
        self.queue.async { [weak self] in
            self?.performJumpToLocation(location)
        }
    }
    
    func performJumpToLocation(_ location: ChapterLocation) {
        if self.readyForPlayback {
            self.updateCursorAndRequestPlaybackFor(location)
        } else {
            self.queuedLocation = location
        }
    }
    
    func updateCursorAndRequestPlaybackFor(_ location: ChapterLocation) {
        var possibleDestinationLocation: ChapterLocation? = location
        let locationBeforeNavigation = self.currentChapterLocation
        // Check to see if our playback location is in the next chapter
        if let timeIntoNextChapter = location.timeIntoNextChapter {

            // Attempt to move the cursor forward indicating
            // there is a next chapter for us to play.
            if let newCursor = self.cursor.next() {
                self.cursor = newCursor
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(timeIntoNextChapter)

            // If there is no next chapter, then we are at the end of the book
            // and we skip to the end.
            } else {
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(self.chapterAtCursor.duration)
            }

        // Check if playback location is in the previous chapter
        } else if let timeIntoPreviousChapter = location.secondsBeforeStart {

            // Attempt to move the cursor backwards indicating
            // there is a previous chapter for us to play.
            if let newCursor = self.cursor.prev() {
                self.cursor = newCursor
                let durationOfChapter =  self.chapterAtCursor.duration
                let playheadOffset = durationOfChapter - timeIntoPreviousChapter
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(max(0, playheadOffset))

            // If there is no previous chapter, we are at the start of the book
            // and skip to the beginning.
            } else {
                possibleDestinationLocation = self.chapterAtCursor.chapterWith(0)
            }
        }
        
        guard let destinationLocation = possibleDestinationLocation else { return }
        
        // Not all playhead movement costs the same. In order to ensure snappy and consistent
        // behavior from FAEPlaybackEngine, we must be careful about how many calls we make to
        // `[FAEPlaybackEngine playForAudiobookID:partNumber:chapterNumber:offset:sessionKey:licenseID]`.
        // Meanwhile, calls to `[FAEPlaybackEngine setCurrentOffset]` are cheap and can be made repeatedly.
        // Because of this we must determine what kind of request we have received before proceeding.
        //
        // If moving the playhead stays in the same file, then the update is instant and we are still
        // ready to get a new request.
        let isSeekOperation = self.isSeekOperation(
            locationBeforeNavigation: locationBeforeNavigation,
            destinationLocation: destinationLocation
        )
        
        // Seek operations are very cheap and move the playhead almost instantly.
        // They can be performed repeatedly within a chapter without fail.
        if isSeekOperation {
            FAEAudioEngine.shared()?.playbackEngine?.currentOffset = UInt(destinationLocation.playheadOffset)
            self.delegates.allObjects.forEach({ (delegate) in
                delegate.player(self, didBeginPlaybackOf: destinationLocation)
            })
        // Resuming playback from the last point is also practically free.
        } else if self.isResumeDescription(destinationLocation) {
            FAEAudioEngine.shared()?.playbackEngine?.resume()
        // This is the expensive path, so instead of making the request immediately
        // we queue it and trash the existing request if a new one comes in.
        } else {
            self.willBeReadyAt = Date().addingTimeInterval(self.debounceBufferTime)
            self.queuedLocation = destinationLocation
            self.queueChapterManipulation()
        }
    }
    
    func queueChapterManipulation() {
        self.queue.asyncAfter(deadline: self.dispatchDeadline) { [weak self] in
            self?.attemptQueuedPlayheadManipulation()
        }
    }
    
    func isSeekOperation(locationBeforeNavigation: ChapterLocation?, destinationLocation: ChapterLocation) -> Bool {
        return self.currentBookIsPlaying && self.locationsPointToTheSameChapter(lhs: destinationLocation, rhs: locationBeforeNavigation)
    }

    func attemptQueuedPlayheadManipulation() {
        guard let destinationLocation = self.queuedLocation else {
            return
        }
        if Date() < self.willBeReadyAt {
            self.queueChapterManipulation()
        } else {
            self.playAtLocation(destinationLocation)
            self.queuedLocation = nil
        }
    }

    func playAtLocation(_ location: ChapterLocation) {
        print("DEANDEBUG chapter update \(location)")
        FAEAudioEngine.shared()?.playbackEngine?.play(
            forAudiobookID: self.audiobookID,
            partNumber: location.part,
            chapterNumber: location.number,
            offset: UInt(location.playheadOffset),
            sessionKey: self.sessionKey,
            licenseID: self.licenseID
        )
    }

    func locationsPointToTheSameChapter(lhs: ChapterLocation?, rhs: ChapterLocation?) -> Bool {
        guard let lhs = lhs else { return false }
        guard let rhs = rhs else { return false }
        return lhs.part == rhs.part && lhs.number == rhs.number
    }

    func currentChapterIsAt(part: UInt, number: UInt) -> Bool {
        guard let chapter = self.currentChapterLocation else { return false }
        return chapter.part == part &&
            chapter.number == number
    }

    func isResumeDescription(_ chapter: ChapterLocation) -> Bool {
        guard let resumeDescription = self.resumePlaybackLocation else {
            return false
        }
        return resumeDescription === chapter
    }
}

extension FindawayPlayer: AudiobookLifecycleManagerDelegate {
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifeCycleManager) {
        DispatchQueue.main.async { [weak self] () -> Void in
            self?.handleLifecycleManagerUpdate(hasBeenVerified: audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified)
        }
    }
    
    func handleLifecycleManagerUpdate(hasBeenVerified: Bool) {
        self.queue.sync {
            self.audioEngineDatabaseHasBeenVerified  = hasBeenVerified
        }

        if let location = self.queuedLocation {
            self.jumpToLocation(location)
        }
    }
}

extension FindawayPlayer: FindawayPlaybackNotificationHandlerDelegate {
    func audioEnginePlaybackStreaming(_ notificationHandler: FindawayPlaybackNotificationHandler, for chapter: FAEChapterDescription) { }
    
    func audioEnginePlaybackLoaded(_ notificationHandler: FindawayPlaybackNotificationHandler, for chapter: FAEChapterDescription) { }
    
    func audioEnginePlaybackStarted(_ notificationHandler: FindawayPlaybackNotificationHandler, for findawayChapter: FAEChapterDescription) {
        self.queue.async { [weak self] in
            self?.handlePlaybackStartedFor(findawayChapter: findawayChapter)
        }
    }
    
    func handlePlaybackStartedFor(findawayChapter: FAEChapterDescription) {
        if !self.currentChapterIsAt(part: findawayChapter.partNumber, number: findawayChapter.chapterNumber) {
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
    
    func notifyDelegatesOfPlaybackFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didBeginPlaybackOf: chapter)
        }
    }
    
    func audioEnginePlaybackPaused(_ notificationHandler: FindawayPlaybackNotificationHandler, for findawayChapter: FAEChapterDescription) {
        if self.currentChapterIsAt(part: findawayChapter.partNumber, number: findawayChapter.chapterNumber) {
            if let currentChapter = self.currentChapterLocation {
                DispatchQueue.main.async { [weak self] () -> Void in
                    self?.notifyDelegatesOfPauseFor(chapter: currentChapter)
                }
            }
        }
    }

    
    func notifyDelegatesOfPauseFor(chapter: ChapterLocation) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.player(self, didStopPlaybackOf: chapter)
        }
    }
}
