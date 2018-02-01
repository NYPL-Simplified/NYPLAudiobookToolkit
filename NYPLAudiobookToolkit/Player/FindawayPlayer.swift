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
    var isPlaying: Bool {
        return FAEAudioEngine.shared()?.playbackEngine?.playerStatus == FAEPlayerStatus.playing
    }

    private var currentFindawayChapter: FAEChapterDescription? {
        return FAEAudioEngine.shared()?.playbackEngine?.currentLoadedChapter()
    }
    private var bookIsLoaded: Bool {
        guard let loadedAudiobookID = self.currentFindawayChapter?.audiobookID else { return false }
        guard let manifestAudiobookID = self.spine.first?.audiobookID else { return false }
        return loadedAudiobookID == manifestAudiobookID
    }

    private let spine: [FindawayFragment]
    public init(spine: [FindawayFragment]) {
        self.spine = spine
    }
    
    func skipForward() {
        let someTimeFromNow = (FAEAudioEngine.shared()?.playbackEngine?.currentOffset ?? 0) + 15
        FAEAudioEngine.shared()?.playbackEngine?.currentOffset = someTimeFromNow
    }
    
    func skipBack() {
        let possibleOffset = (FAEAudioEngine.shared()?.playbackEngine?.currentOffset ?? 0) + 15
        let someTimeBeforeNow = possibleOffset > 0 ? possibleOffset : 0
        FAEAudioEngine.shared()?.playbackEngine?.currentOffset = someTimeBeforeNow
    }
    
    func play() {
        let possibleFragment = self.spine.first
        guard let fragment = possibleFragment else { return }
        if self.bookIsLoaded {
            FAEAudioEngine.shared()?.playbackEngine?.resume()
        } else {
            FAEAudioEngine.shared()?.playbackEngine?.play(
                forAudiobookID: fragment.audiobookID,
                partNumber: fragment.partNumber,
                chapterNumber: fragment.chapterNumber,
                offset: 0,
                sessionKey: fragment.sessionKey,
                licenseID: fragment.licenseID
            )
        }
    }
    
    func pause() {
        FAEAudioEngine.shared()?.playbackEngine?.pause()
    }
}
