//
//  PlayerMock.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/7/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit

class PlayerMock: Player {
    var isPlaying: Bool = false
    
    func chapterIsPlaying(_ location: ChapterLocation) -> Bool {
        return false
    }
    
    func play() { }
    
    func pause() { }
    
    func skipForward() { }
    
    func skipBack() { }
    
    func jumpToLocation(_ location: ChapterLocation) { }
    
    func registerDelegate(_ delegate: PlayerDelegate) { }
    
    func removeDelegate(_ delegate: PlayerDelegate) { }
}
