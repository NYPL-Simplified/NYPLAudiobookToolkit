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
    func playAtLocation(_ location: ChapterLocation) { }
    
    func movePlayheadToLocation(_ location: ChapterLocation) { }
    
    var playbackRate: PlaybackRate = .normalTime
    
    var currentChapterLocation: ChapterLocation? {
        return self.currentChapter
    }
    
    var isPlaying: Bool = false
    
    private var currentChapter: ChapterLocation?
    
    func chapterIsPlaying(_ location: ChapterLocation) -> Bool {
        return currentChapter == location
    }
    
    func play() { }
    
    func pause() { }
    
    func skipForward() { }
    
    func skipBack() { }
    
    func registerDelegate(_ delegate: PlayerDelegate) { }
    
    func removeDelegate(_ delegate: PlayerDelegate) { }

    convenience init (currentChapter: ChapterLocation?) {
        self.init()
        self.currentChapter = currentChapter

    }
}
