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

    var isLoaded: Bool = false

    func playAtLocation(_ location: ChapterLocation) { }
    
    func movePlayheadToLocation(_ location: ChapterLocation) { }
    
    var playbackRate: PlaybackRate = .normalTime
    
    var currentChapterLocation: ChapterLocation? {
        return self.currentChapter
    }
    
    var isPlaying: Bool = false
    
    private var currentChapter: ChapterLocation?
    
    func play() { }
    
    func pause() { }

    func skipPlayhead(_ timeInterval: TimeInterval, completion: ((ChapterLocation) -> ())?) { }

    func unload() { }
    
    func registerDelegate(_ delegate: PlayerDelegate) { }
    
    func removeDelegate(_ delegate: PlayerDelegate) { }

    convenience init? (currentChapter: ChapterLocation?) {
        self.init()
        self.currentChapter = currentChapter
        self.isLoaded = true
        
        return nil
    }
}
