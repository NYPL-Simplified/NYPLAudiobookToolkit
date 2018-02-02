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
    weak var delegate: PlayerDelegate?

    /// We ought to crash if this does not exist
    private var sessionKey: String {
        return (self.spine.first?.audiobookID)!
    }

    /// We ought to crash if this does not exist
    private var licenseID: String {
        return (self.spine.first?.licenseID)!
    }

    /// We ought to crash if this does not exist
    private var audiobookID: String {
        return (self.spine.first?.licenseID)!
    }
    
    private var currentOffset: UInt {
        return FAEAudioEngine.shared()?.playbackEngine?.currentOffset ?? 0
    }

    var isPlaying: Bool {
        return FAEAudioEngine.shared()?.playbackEngine?.playerStatus == FAEPlayerStatus.playing
    }

    private var currentFindawayChapter: FAEChapterDescription? {
        return FAEAudioEngine.shared()?.playbackEngine?.currentLoadedChapter()
    }
    private var bookIsLoaded: Bool {
        guard let loadedAudiobookID = self.currentFindawayChapter?.audiobookID else { return false }
        return loadedAudiobookID == self.sessionKey
    }

    private let spine: [FindawayFragment]
    public init(spine: [FindawayFragment]) {
        self.spine = spine
    }
    
    func skipForward() {
        let someTimeFromNow = self.currentOffset + 15
        self.updatePlaybackWith(self.commandAtOffset(someTimeFromNow))
    }
    
    func skipBack() {
        let possibleOffset = self.currentOffset + 15
        let someTimeBeforeNow = possibleOffset > 0 ? possibleOffset : 0
        self.updatePlaybackWith(self.commandAtOffset(someTimeBeforeNow))
    }
    
    func play() {
        self.updatePlaybackWith(self.commandAtOffset(0))
    }
    
    
    func pause() {
        FAEAudioEngine.shared()?.playbackEngine?.pause()
    }
    
    func updatePlaybackWith(_ playerCommand: PlayerCommand) {
        if self.isPlaying {
            if self.chapterIsCurrentlyPlaying(playerCommand.chapter) {
                FAEAudioEngine.shared()?.playbackEngine?.currentOffset = playerCommand.offset
            } else {
                self.playWithCommand(playerCommand)
            }
        } else {
            self.playWithCommand(playerCommand)
        }
    }
    
    func playWithCommand(_ command: PlayerCommand) {
        FAEAudioEngine.shared()?.playbackEngine?.play(
            forAudiobookID: self.audiobookID,
            partNumber: playerCommand.chapter.part,
            chapterNumber: playerCommand.chapter.number,
            offset: playerCommand.offset,
            sessionKey: self.sessionKey,
            licenseID: self.licenseID
        )
    }
    
    func chapterIsCurrentlyPlaying(_ chapter: ChapterDescription) -> Bool {
        guard let findawayChapter = self.currentFindawayChapter else { return false }
        return findawayChapter.partNumber == chapter.part &&
            findawayChapter.chapterNumber == chapter.number
        
    }
    
    func commandAtOffset(_ offset: UInt) -> PlayerCommand {
        let fragment = self.spine.first!
        let findaway = self.currentFindawayChapter
        let command = DefaultPlayerCommand(
            offset: 0,
            chapter: DefaultChapterDescription(
                number: findaway?.chapterNumber ?? fragment.chapterNumber,
                part: findaway?.partNumber ?? fragment.partNumber
            )
        )
        return command
    }
}
