//
//  Player.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import Foundation


/// Receive updates from player as events happen
@objc public protocol PlayerDelegate: class {
    func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation)
    func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation)
}

/// Objects that impelment Player should wrap a PlaybackEngine.
/// This does not specifically refer to AVPlayer, but could also be
/// FAEPlaybackEngine, or another engine that handles DRM content.
@objc public protocol Player {
    weak var delegate: PlayerDelegate? { get set }
    func play()
    func pause()
    func skipForward()
    func skipBack()
    var isPlaying: Bool { get }
    func jumpToLocation(_ location: ChapterLocation)
}

/// *EXPERIMENTAL AND LIKELY TO CHANGE*
/// This protocol is supposed to represent how to issue complex commands to the player.
/// IE: stop and seek to 3:00
/// IE: stop and skip to Chapter 3
///
/// This protocol is supposed to represent metadata associated with a chapter.
/// It is intended to be used as a way to seek through the track.
///
/// The reason this is still experimental is that it likely to duplicate
/// functionality needed by the table of contents. This object will
/// likely need information about seeking between chapters and skipping to
/// new chapters as well.
///
/// This is also likely to change as the interface for doing this with
/// AVPlayer & FAEPlaybackEngine are quite different.
@objc public final class ChapterLocation: NSObject {
    let number: UInt
    let part: UInt
    let duration: TimeInterval
    let startOffset: TimeInterval
    let playheadOffset: TimeInterval

    var secondsBeforeStart: TimeInterval? {
        var timeInterval: TimeInterval? = nil
        if self.playheadOffset < 0 {
            timeInterval = abs(self.playheadOffset)
        }
        return timeInterval
    }
    
    var timeIntoNextChapter: TimeInterval? {
        var timeInterval: TimeInterval? = nil
        if self.playheadOffset > self.duration {
            timeInterval = self.playheadOffset - self.duration
        }
        return timeInterval
    }

    init?(number: UInt, part: UInt, duration: TimeInterval, startOffset: TimeInterval, playheadOffset: TimeInterval) {
        guard startOffset <= duration else {
            return nil
        }
        
        self.number = number
        self.part = part
        self.duration = duration
        self.startOffset = startOffset
        self.playheadOffset = playheadOffset
    }

    func chapterWith(_ offset: TimeInterval) -> ChapterLocation? {
        return ChapterLocation(
            number: self.number,
            part: self.part,
            duration: self.duration,
            startOffset: self.startOffset,
            playheadOffset: offset
        )
    }
    public override var description: String {
        return "ChapterLocation P \(self.part) CN \(self.number); PH \(self.playheadOffset) D \(self.duration)"
    }
}
