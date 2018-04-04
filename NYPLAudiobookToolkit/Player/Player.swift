//
//  Player.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import Foundation

@objc public enum PlaybackRate: Int {
    case threeQuartersTime = 75
    case normalTime = 100
    case oneAndAQuarterTime = 125
    case oneAndAHalfTime = 150
    case doubleTime = 200
    
    static func convert(rate: PlaybackRate) -> Float {
        return Float(rate.rawValue) * 0.01
    }
}

/// Receive updates from player as events happen
@objc public protocol PlayerDelegate: class {
    func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation)
    func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation)
}

/// Objects that impelment Player should wrap a PlaybackEngine.
/// This does not specifically refer to AVPlayer, but could also be
/// FAEPlaybackEngine, or another engine that handles DRM content.
@objc public protocol Player {
    func play()
    func pause()
    func skipForward()
    func skipBack()
    var isPlaying: Bool { get }
    var currentChapterLocation: ChapterLocation? { get }
    var playbackRate: PlaybackRate { get set }
    func jumpToLocation(_ location: ChapterLocation)

    func registerDelegate(_ delegate: PlayerDelegate)
    func removeDelegate(_ delegate: PlayerDelegate)
}

/// This class represents a location in a book.
@objc public final class ChapterLocation: NSObject {
    let title: String?
    let number: UInt
    let part: UInt
    let duration: TimeInterval
    let startOffset: TimeInterval
    let playheadOffset: TimeInterval

    var timeRemaining: TimeInterval {
        return self.duration - self.playheadOffset
    }

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
    
    public func inSameChapter(other: ChapterLocation?) -> Bool {
        guard let rhs = other else { return false }
        return self.number == rhs.number &&
            self.part == rhs.part
    }

    public init?(number: UInt, part: UInt, duration: TimeInterval, startOffset: TimeInterval, playheadOffset: TimeInterval, title: String?) {
        guard startOffset <= duration else {
            return nil
        }
        
        self.number = number
        self.part = part
        self.duration = duration
        self.startOffset = startOffset
        self.playheadOffset = playheadOffset
        self.title = title
        
    }

    func chapterWith(_ offset: TimeInterval) -> ChapterLocation? {
        return ChapterLocation(
            number: self.number,
            part: self.part,
            duration: self.duration,
            startOffset: self.startOffset,
            playheadOffset: offset,
            title: self.title
        )
    }
    public override var description: String {
        return "ChapterLocation P \(self.part) CN \(self.number); PH \(self.playheadOffset) D \(self.duration)"
    }
}
