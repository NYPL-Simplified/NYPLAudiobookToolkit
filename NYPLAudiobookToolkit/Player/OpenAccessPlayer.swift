//
//  OpenAccessPlayer.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class OpenAccessPlayer: NSObject, Player {
    var delegate: PlayerDelegate?
    
    func updatePlaybackWith(_ playerCommand: PlayerCommand) {

    }
    
    func skipForward() {

    }
    
    func skipBack() {

    }
    
    var isPlaying: Bool {
        return false
    }

    func play() {
        
    }
    
    func pause() {
        
    }
    
    private let spine: [OpenAccessFragment]
    public init(spine: [OpenAccessFragment]) {
        self.spine = spine
    }
}
