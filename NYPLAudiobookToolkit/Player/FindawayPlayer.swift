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
        guard self.currentBookIsPlaying else {
            return nil
        }
        let findaway = self.currentFindawayChapter
        let duration = self.currentBookIsPlaying ? TimeInterval(self.currentDuration) : (self.firstSpineElement.duration ?? 0)
        return ChapterLocation(
            number: findaway?.chapterNumber ?? self.firstSpineElement.chapterNumber,
            part: findaway?.partNumber ?? self.firstSpineElement.partNumber,
            duration: duration,
            startOffset: 0,
            playheadOffset: TimeInterval(self.currentOffset)
        )
    }
    weak var delegate: PlayerDelegate?
    private var resumePlaybackDescription: ChapterLocation?
    // Only queue the last issued command if they are issued before Findaway has been verified
    private var queuedLocation: ChapterLocation?
    private var readyForPlayback = false {
        didSet {
            if let location = self.queuedLocation {
                self.playAtLocation(location)
                self.queuedLocation = nil
            }
        }
    }

    private var sessionKey: String {
        return self.firstSpineElement.sessionKey
    }

    private var licenseID: String {
        return self.firstSpineElement.licenseID
    }

    private var audiobookID: String {
        return self.firstSpineElement.audiobookID
    }

    /// If no book is loaded, AudioEngine returns 0, so this is consistent with their behavior
    private var currentOffset: UInt {
        return FAEAudioEngine.shared()?.playbackEngine?.currentOffset ?? 0
    }

    /// If no book is loaded, AudioEngine returns 0, so this is consistent with their behavior
    private var currentDuration: UInt {
        return FAEAudioEngine.shared()?.playbackEngine?.currentDuration ?? 0
    }

    var currentBookIsPlaying: Bool {
        return self.isPlaying && self.bookIsLoaded
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

    private let firstSpineElement: FindawaySpineElement
    private let spine: [FindawaySpineElement]
    private var eventHandler: FindawayPlaybackNotificationHandler
    public init(spine: [FindawaySpineElement], spineElement: FindawaySpineElement, eventHandler: FindawayPlaybackNotificationHandler) {
        
        self.spine = spine
        self.eventHandler = eventHandler
        self.firstSpineElement = spineElement
        super.init()
        self.eventHandler.delegate = self
    }
    
    convenience init(spine: [FindawaySpineElement], spineElement: FindawaySpineElement) {
        self.init(spine: spine, spineElement: spineElement, eventHandler: DefaultFindawayPlaybackNotificationHandler())
    }

    func skipForward() {
        let someTimeFromNow = self.currentOffset + 15
        let offsetDescription = self.currentChapterLocation?.chapterWith(TimeInterval(someTimeFromNow))
        if let description = offsetDescription {
            self.jumpToChapter(description)
        }
    }

    func skipBack() {
        let someTimeAgo = Int(self.currentOffset) - 15
        let timeToGoBackTo = UInt(max(0, someTimeAgo))
        let offsetDescription = self.currentChapterLocation?.chapterWith(TimeInterval(timeToGoBackTo))
        if let description = offsetDescription {
            self.jumpToChapter(description)
        }
    }

    func play() {
        if let resumeCommand = self.resumePlaybackDescription {
            self.jumpToChapter(resumeCommand)
        } else {
            if let description = self.currentChapterLocation?.chapterWith(0) {
                self.jumpToChapter(description)
            }
        }
    }

    
    func pause() {
        self.resumePlaybackDescription = self.currentChapterLocation
        FAEAudioEngine.shared()?.playbackEngine?.pause()
    }
    
    func jumpToChapter(_ chapter: ChapterLocation) {
        guard !self.readyForPlayback else {
            self.queuedLocation = chapter
            return
        }

        if self.currentBookIsPlaying {
            if self.chapterIsCurrentlyPlaying(chapter) {
                FAEAudioEngine.shared()?.playbackEngine?.currentOffset = UInt(chapter.playheadOffset)
                self.delegate?.player(self, didBeginPlaybackOf: chapter)
            } else {
                self.playAtLocation(chapter)
            }
        } else if self.isResumeDescription(chapter) {
            FAEAudioEngine.shared()?.playbackEngine?.resume()
        } else {
            self.playAtLocation(chapter)
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
    
    func chapterIsCurrentlyPlaying(_ chapter: ChapterLocation) -> Bool {
        guard let findawayChapter = self.currentFindawayChapter else { return false }
        return findawayChapter.partNumber == chapter.part &&
            findawayChapter.chapterNumber == chapter.number
    }

    func isResumeDescription(_ chapter: ChapterLocation) -> Bool {
        guard let resumeDescription = self.resumePlaybackDescription else {
            return false
        }
        return resumeDescription === chapter
    }
}

extension FindawayPlayer: AudiobookLifecycleManagerDelegate {
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifeCycleManager) {
        self.readyForPlayback = audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified
    }
    
    func audiobookLifecycleManager(_ audiobookLifecycleManager: AudiobookLifeCycleManager, didRecieve error: AudiobookError) {
    }
}

extension FindawayPlayer: FindawayPlaybackNotificationHandlerDelegate {
    func audioEngineChapterPlaybackStarted(_ notificationHandler: FindawayPlaybackNotificationHandler) {
        if let chapter = self.currentChapterLocation {
            self.delegate?.player(self, didBeginPlaybackOf: chapter)
        }
    }
    
    func audioEngineChapterPlaybackPaused(_ notificationHandler: FindawayPlaybackNotificationHandler) {
        if let chapter = self.currentChapterLocation {
            self.delegate?.player(self, didStopPlaybackOf: chapter)
        }
    }
}
