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

    func play() {
        let possibleFragment = self.spine.first
        guard let fragment = possibleFragment else { return }
        FAEAudioEngine.shared()?.playbackEngine?.play(
            forAudiobookID: fragment.audiobookID,
            partNumber: fragment.partNumber,
            chapterNumber: fragment.chapterNumber,
            offset: 0,
            sessionKey: fragment.sessionKey,
            licenseID: fragment.licenseID
        )
    }
    
    func pause() {
        FAEAudioEngine.shared()?.playbackEngine?.pause()
    }
    
    private let spine: [FindawayFragment]
    public init(spine: [FindawayFragment]) {
        self.spine = spine
    }
}
