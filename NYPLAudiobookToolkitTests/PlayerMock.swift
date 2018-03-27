//
//  PlayerMock.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/7/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit

typealias Callback = () -> Void
class PlayerMock: Player {
    var playbackRate: PlaybackRate = .normalTime
    
    var currentChapterLocation: ChapterLocation? {
        return self.currentChapter
    }
    
    var isPlaying: Bool = false
    
    private var currentChapter: ChapterLocation?
    
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

    convenience init (currentChapter: ChapterLocation?) {
        self.init()
        self.currentChapter = currentChapter

    }
}
