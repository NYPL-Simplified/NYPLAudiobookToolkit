//
//  OpenAccessPlayer.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

final class OpenAccessPlayer: NSObject, Player {
    func seekTo(_ offsetInChapter: Float) {
    }
    
    var delegate: PlayerDelegate?
    
    func jumpToLocation(_ chapter: ChapterLocation) {

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
}
