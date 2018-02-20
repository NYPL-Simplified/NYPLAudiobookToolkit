//
//  FindawayPlayer.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

class FindawayPlayer: NSObject, Player {
    private var currentChapterLocation: ChapterLocation? {
        let findaway = self.currentFindawayChapter
        let possibleDuration = self.currentDuration ?? self.chapterAtCursor?.duration
        guard let chapterNumber = (findaway?.chapterNumber ?? self.chapterAtCursor?.number) else { return nil }
        guard let partNumber = (findaway?.partNumber ?? self.chapterAtCursor?.part) else { return nil }
        guard let duration = possibleDuration else { return nil }
        return ChapterLocation(
            number: chapterNumber,
            part: partNumber,
            duration: duration,
            startOffset: 0,
            playheadOffset: TimeInterval(self.currentOffset)
        )
    }
    weak var delegate: PlayerDelegate?
    private var resumePlaybackLocation: ChapterLocation?
    // Only queue the last issued command if they are issued before Findaway has been verified
    private var queuedLocation: ChapterLocation?
    private var readyForPlayback = false {
        didSet {
            if let location = self.queuedLocation {
                self.jumpToLocation(location)
                self.queuedLocation = nil
            }
        }
    }

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

    
    private var currentDuration: TimeInterval? {
        var possibleDuration: TimeInterval? = nil
        if self.currentBookIsPlaying {
            /// If no book is loaded, AudioEngine returns 0, so this is consistent with their behavior
            print("DEANDEBUG current duration from findawaySDK \(FAEAudioEngine.shared()?.playbackEngine?.currentDuration)")
            possibleDuration = TimeInterval(FAEAudioEngine.shared()?.playbackEngine?.currentDuration ?? 0)
        }
        return possibleDuration
    }

    private var currentBookIsPlaying: Bool {
        return self.isPlaying && self.bookIsLoaded
    }
    
    private var chapterAtCursor: ChapterLocation? {
        return self.cursor?.currentElement.chapter
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

    private var cursor: Cursor<SpineElement>?
    private let spineElement: FindawaySpineElement
    private var eventHandler: FindawayPlaybackNotificationHandler

    public init(spineElement: FindawaySpineElement, eventHandler: FindawayPlaybackNotificationHandler, spine: [SpineElement]) {
        self.eventHandler = eventHandler
        self.spineElement = spineElement
        self.cursor = Cursor(data: spine, index: 0)
        super.init()
        self.eventHandler.delegate = self
    }
    
    convenience init(spineElement: FindawaySpineElement, spine: [SpineElement]) {
        self.init(spineElement: spineElement, eventHandler: DefaultFindawayPlaybackNotificationHandler(), spine: spine)
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
        if let resumeCommand = self.resumePlaybackLocation {
            self.jumpToLocation(resumeCommand)
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
        var possibleDestinationChapter: ChapterLocation? = location
        guard !self.readyForPlayback else {
            self.queuedLocation = location
            return
        }

        if let timeIntoNextChapter = location.timeIntoNextChapter {
            self.cursor = self.cursor?.next()
            possibleDestinationChapter = self.cursor?.currentElement.chapter.chapterWith(timeIntoNextChapter)
        } else if let timeIntoPreviousChapter = location.secondsBeforeStart {
            self.cursor = self.cursor?.prev()
            let durationOfChapter = (self.cursor?.currentElement.chapter.duration ?? 0)
            let playheadOffset = durationOfChapter - timeIntoPreviousChapter
            possibleDestinationChapter = self.cursor?.currentElement.chapter.chapterWith(max(0, playheadOffset))
        }
        
        guard let destinationChapter = possibleDestinationChapter else { return }
    
        if self.currentBookIsPlaying {
            if self.currentChapterIsAt(part: destinationChapter.part, number: destinationChapter.number) {
                FAEAudioEngine.shared()?.playbackEngine?.currentOffset = UInt(destinationChapter.playheadOffset)
                self.delegate?.player(self, didBeginPlaybackOf: destinationChapter)
            } else {
                self.playAtLocation(destinationChapter)
            }
        } else if self.isResumeDescription(destinationChapter) {
            FAEAudioEngine.shared()?.playbackEngine?.resume()
        } else {
            self.playAtLocation(destinationChapter)
        }
    }
    
    func playAtLocation(_ chapter: ChapterLocation) {
        FAEAudioEngine.shared()?.playbackEngine?.play(
            forAudiobookID: self.audiobookID,
            partNumber: chapter.part,
            chapterNumber: chapter.number,
            offset: UInt(chapter.playheadOffset),
            sessionKey: self.sessionKey,
            licenseID: self.licenseID
        )
    }

    func cursorIsAt(part: UInt, number: UInt) -> Bool {
        guard let cursorCapter = self.chapterAtCursor else { return false }
        return cursorCapter.part == part &&
            cursorCapter.number == number
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
        self.readyForPlayback = audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified
    }
    
    // TODO: Update this to pass the chapter that the error happened to instead of audiobook id
    func audiobookLifecycleManager(_ audiobookLifecycleManager: AudiobookLifeCycleManager, didRecieve error: AudiobookError) {
    }
}

extension FindawayPlayer: FindawayPlaybackNotificationHandlerDelegate {
    func audioEnginePlaybackStarted(_ notificationHandler: FindawayPlaybackNotificationHandler, for findawayChapter: FAEChapterDescription) {
        self.updateCursorTo(findawayChapter: findawayChapter) { (chapter) in
            if let chapter = chapter {
                self.delegate?.player(self, didBeginPlaybackOf: chapter)
            }
        }
    }
    
    func audioEnginePlaybackPaused(_ notificationHandler: FindawayPlaybackNotificationHandler, for findawayChapter: FAEChapterDescription) {
        if self.currentChapterIsAt(part: findawayChapter.partNumber, number: findawayChapter.chapterNumber) {
            if let currentChapter = self.currentChapterLocation {
                self.delegate?.player(self, didStopPlaybackOf: currentChapter)
            }
        }
    }

    func updateCursorTo(findawayChapter: FAEChapterDescription, completion: (_ chapter: ChapterLocation?) -> Void) {
        var currentChapter = self.currentChapterLocation
        if !self.cursorIsAt(part: findawayChapter.partNumber, number: findawayChapter.chapterNumber) {
            let newCursor = self.cursor?.cursor(at: { (spineElement) -> Bool in
                return spineElement.chapter.number == findawayChapter.chapterNumber && spineElement.chapter.part == findawayChapter.partNumber
            })
            self.cursor = newCursor
            currentChapter = self.chapterAtCursor
        }
        completion(currentChapter)
    }
}
