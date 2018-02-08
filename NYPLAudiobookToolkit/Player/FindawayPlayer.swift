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
    private var currentChapterDescription: ChapterDescription {
        let findaway = self.currentFindawayChapter
        let duration = self.currentBookIsPlaying ? TimeInterval(self.currentDuration) : (self.firstFragment.duration ?? 0)
        return DefaultChapterDescription(
            number: findaway?.chapterNumber ?? self.firstFragment.chapterNumber,
            part: findaway?.partNumber ?? self.firstFragment.partNumber,
            duration: duration,
            offset: TimeInterval(self.currentOffset)
        )
    }
    weak var delegate: PlayerDelegate?
    private var resumePlaybackCommand: ChapterDescription?
    // Only queue the last issued command if they are issued before Findaway has been verified
    private var queuedCommand: ChapterDescription?
    private var readyForPlayback = false {
        didSet {
            if let command = self.queuedCommand {
                self.playWithCommand(command)
                self.queuedCommand = nil
            }
        }
    }

    private var sessionKey: String {
        return self.firstFragment.sessionKey
    }

    private var licenseID: String {
        return self.firstFragment.licenseID
    }

    private var audiobookID: String {
        return self.firstFragment.audiobookID
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

    private let firstFragment: FindawayFragment
    private let spine: [FindawayFragment]
    private var eventHandler: FindawayPlaybackNotificationHandler
    public init(spine: [FindawayFragment], fragment: FindawayFragment, eventHandler: FindawayPlaybackNotificationHandler) {
        self.spine = spine
        self.eventHandler = eventHandler
        self.firstFragment = fragment
        super.init()
        self.eventHandler.delegate = self
    }
    
    convenience init(spine: [FindawayFragment], fragment: FindawayFragment) {
        self.init(spine: spine, fragment: fragment, eventHandler: DefaultFindawayPlaybackNotificationHandler())
    }

    func skipForward() {
        let someTimeFromNow = self.currentOffset + 15
        let offsetDescription = self.currentChapterDescription.chapterWith(TimeInterval(someTimeFromNow))
        self.jumpToChapter(offsetDescription)
    }

    func skipBack() {
        let someTimeAgo = Int(self.currentOffset) - 15
        let timeToGoBackTo = UInt(max(0, someTimeAgo))
        let offsetDescription = self.currentChapterDescription.chapterWith(TimeInterval(timeToGoBackTo))
        self.jumpToChapter(offsetDescription)
    }

    func play() {
        if let resumeCommand = self.resumePlaybackCommand {
            self.jumpToChapter(resumeCommand)
        } else {
            self.jumpToChapter(
                self.currentChapterDescription.chapterWith(0)
            )
        }
    }

    
    func pause() {
        if let chapter = self.currentFindawayChapter {
            self.resumePlaybackCommand = DefaultChapterDescription(
                number: chapter.chapterNumber,
                part: chapter.partNumber,
                duration: TimeInterval(self.currentDuration),
                offset: TimeInterval(self.currentOffset)
            )
        }
        FAEAudioEngine.shared()?.playbackEngine?.pause()
    }
    
    func jumpToChapter(_ description: ChapterDescription) {
        guard !self.readyForPlayback else {
            self.queuedCommand = description
            return
        }

        if self.bookIsLoaded && self.isPlaying {
            if self.chapterIsCurrentlyPlaying(description) {
                FAEAudioEngine.shared()?.playbackEngine?.currentOffset = UInt(description.offset)
            } else {
                self.playWithCommand(description)
            }
        } else {
            self.playWithCommand(description)
        }
    }
    
    func playWithCommand(_ chapter: ChapterDescription) {
        FAEAudioEngine.shared()?.playbackEngine?.play(
            forAudiobookID: self.audiobookID,
            partNumber: chapter.part,
            chapterNumber: chapter.number,
            offset: UInt(chapter.offset),
            sessionKey: self.sessionKey,
            licenseID: self.licenseID
        )
    }
    
    func chapterIsCurrentlyPlaying(_ chapter: ChapterDescription) -> Bool {
        guard let findawayChapter = self.currentFindawayChapter else { return false }
        return findawayChapter.partNumber == chapter.part &&
            findawayChapter.chapterNumber == chapter.number
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
        if let chapter = self.currentFindawayChapter {
            let chapterDescription = DefaultChapterDescription(
                number: chapter.chapterNumber,
                part: chapter.partNumber,
                duration: TimeInterval(self.currentDuration),
                offset: TimeInterval(self.currentOffset)
            )

            DispatchQueue.main.async { [weak self] in
                if let strongSelf = self {
                    strongSelf.delegate?.player(strongSelf, didBeginPlaybackOf: chapterDescription)
                }
            }
        }
    }
    
    func audioEngineChapterPlaybackPaused(_ notificationHandler: FindawayPlaybackNotificationHandler) {
        if let chapter = self.currentFindawayChapter {
            let chapterDescription = DefaultChapterDescription(
                number: chapter.chapterNumber,
                part: chapter.partNumber,
                duration: TimeInterval(self.currentDuration),
                offset: TimeInterval(self.currentOffset)
            )
            DispatchQueue.main.async { [weak self] in
                if let strongSelf = self {
                    strongSelf.delegate?.player(strongSelf, didStopPlaybackOf: chapterDescription)
                }
            }
        }
    }
    
    func playbackNotification() {
    }
}
