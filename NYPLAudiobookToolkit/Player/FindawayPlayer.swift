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
    public func chapterIsPlaying(_ location: ChapterLocation) -> Bool {
        guard self.isPlaying else { return false }
        var chapterIsPlaying = false
        self.queue.sync { [weak self] () -> Void in
            chapterIsPlaying = self?.currentChapterIsAt(part: location.part, number: location.number) ?? false
        }
        return chapterIsPlaying
    }

    private var currentChapterLocation: ChapterLocation? {
        var chapter: ChapterLocation?
        if let chapterAtCursor = self.chapterAtCursor {
            chapter = ChapterLocation(
                number: chapterAtCursor.number,
                part: chapterAtCursor.part,
                duration: chapterAtCursor.duration,
                startOffset: 0,
                playheadOffset: TimeInterval(self.currentOffset),
                title: chapterAtCursor.title
            )
        }
        return chapter
    }

    var delegates: NSHashTable<PlayerDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])
    
    public func registerDelegate(_ delegate: PlayerDelegate) {
        self.delegates.add(delegate)
    }
    
    public func removeDelegate(_ delegate: PlayerDelegate) {
        self.delegates.remove(delegate)
    }

    private var resumePlaybackLocation: ChapterLocation?
    // Only queue the last issued command if they are issued before Findaway has been verified
    private var queuedLocation: ChapterLocation?
    
    /// It is vitally important that modifications to
    /// this variable is only modified synchronously in
    /// the queue.
    private var readyForPlayback = false
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
    
    private var chapterAtCursor: ChapterLocation? {
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
    public init(spineElement: FindawaySpineElement, eventHandler: FindawayPlaybackNotificationHandler, cursor: Cursor<SpineElement>) {
        self.eventHandler = eventHandler
        self.spineElement = spineElement
        self.cursor = cursor
        super.init()
        self.eventHandler.delegate = self
    }
    
    convenience init(spineElement: FindawaySpineElement, cursor: Cursor<SpineElement>) {
        self.init(spineElement: spineElement, eventHandler: DefaultFindawayPlaybackNotificationHandler(), cursor: cursor)
    }

    func skipForward() {
        let someTimeFromNow = self.currentOffset + 15
        let location = self.currentChapterLocation?.chapterWith(TimeInterval(someTimeFromNow))
        if let location = location {
            self.jumpToLocation(location)
        }
    }

    func skipBack() {
        let someTimeAgo = Int(self.currentOffset) - 15
        let location = self.currentChapterLocation?.chapterWith(TimeInterval(someTimeAgo))
        if let location = location {
            self.jumpToLocation(location)
        }
    }

    func play() {
        if let resumeLocation = self.resumePlaybackLocation {
            self.jumpToLocation(resumeLocation)
        } else {
            if let location = self.currentChapterLocation?.chapterWith(0) {
                self.jumpToLocation(location)
            }
        }
    }
    
    func pause() {
        self.resumePlaybackLocation = self.currentChapterLocation
        FAEAudioEngine.shared()?.playbackEngine?.pause()
    }
    
    func jumpToLocation(_ location: ChapterLocation) {
        self.queue.sync { [weak self] () -> Void in
            guard let readyToPlay = self?.readyForPlayback else {
                return
            }
            if readyToPlay {
                self?.performJumpToLocation(location)
            } else {
                self?.queuedLocation = location
            }
        }
    }
    
    func performJumpToLocation(_ location: ChapterLocation) {
        var possibleDestinationLocation: ChapterLocation? = location
        let locationBeforeNavigation = self.currentChapterLocation
        if let timeIntoNextChapter = location.timeIntoNextChapter,
            let newCursor = self.cursor.next() {
            self.cursor = newCursor
            possibleDestinationLocation = self.cursor.currentElement.chapter.chapterWith(timeIntoNextChapter)
            
        } else if let timeIntoPreviousChapter = location.secondsBeforeStart,
            let newCursor = self.cursor.prev() {
            self.cursor = newCursor
            let durationOfChapter =  self.cursor.currentElement.chapter.duration
            let playheadOffset = durationOfChapter - timeIntoPreviousChapter
            possibleDestinationLocation = self.cursor.currentElement.chapter.chapterWith(max(0, playheadOffset))
        }
        
        guard let destinationLocation = possibleDestinationLocation else { return }
        
        if self.currentBookIsPlaying {
            if self.locationsAreEqual(lhs: destinationLocation, rhs: locationBeforeNavigation) {
                FAEAudioEngine.shared()?.playbackEngine?.currentOffset = UInt(destinationLocation.playheadOffset)
                self.delegates.allObjects.forEach({ (delegate) in
                    delegate.player(self, didBeginPlaybackOf: destinationLocation)
                })
            } else {
                self.playAtLocation(destinationLocation)
            }
        } else if self.isResumeDescription(destinationLocation) {
            FAEAudioEngine.shared()?.playbackEngine?.resume()
        } else {
            self.playAtLocation(destinationLocation)
        }
    }
    func playAtLocation(_ location: ChapterLocation) {
        FAEAudioEngine.shared()?.playbackEngine?.play(
            forAudiobookID: self.audiobookID,
            partNumber: location.part,
            chapterNumber: location.number,
            offset: UInt(location.playheadOffset),
            sessionKey: self.sessionKey,
            licenseID: self.licenseID
        )
    }

    func locationsAreEqual(lhs: ChapterLocation?, rhs: ChapterLocation?) -> Bool {
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
            self?.handleLifecycleManagerUpdate(readyForPlayback: audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified)
        }
    }
    
    func handleLifecycleManagerUpdate(readyForPlayback: Bool) {
        self.readyForPlayback = readyForPlayback
        if let location = self.queuedLocation {
            self.jumpToLocation(location)
            self.queuedLocation = nil
        }
    }
}

extension FindawayPlayer: FindawayPlaybackNotificationHandlerDelegate {
    func audioEnginePlaybackStarted(_ notificationHandler: FindawayPlaybackNotificationHandler, for findawayChapter: FAEChapterDescription) {
        self.queue.sync { [weak self] () -> Void in
            self?.handlePlaybackNotificationWith(findawayChapter: findawayChapter)
        }
    }
    
    func handlePlaybackNotificationWith(findawayChapter: FAEChapterDescription) {
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
