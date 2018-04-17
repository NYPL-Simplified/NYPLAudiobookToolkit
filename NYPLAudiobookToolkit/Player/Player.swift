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

    /// Guaranteed to be called on the following scenarios:
    ///   * The playhead crossed to a new chapter
    ///   * The play() method was called
    ///   * The playhead was modified, the result of  jumpToLocation(_), skipForward() or skipBack()
    func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation)

    /// Called to notify that playback has stopped
    /// this should only happen as a result of pause() being called.
    func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation)

    /// Called when the playhead crosses a chapter boundary without direction.
    /// Depending on the underlying playback engine, this could come some time
    /// after the next chapter has begun playing. This should arrive before
    /// `player:didBeginPlaybackOf:` is called.
    func player(_ player: Player, didComplete chapter: ChapterLocation)
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
@objc public final class ChapterLocation: NSObject, Codable {
    let title: String?
    let number: UInt
    let part: UInt
    let duration: TimeInterval
    let startOffset: TimeInterval
    let playheadOffset: TimeInterval
    let audiobookID: String

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
        return self.audiobookID == rhs.audiobookID &&
            self.number == rhs.number &&
            self.part == rhs.part
    }

    public init?(number: UInt, part: UInt, duration: TimeInterval, startOffset: TimeInterval, playheadOffset: TimeInterval, title: String?, audiobookID: String) {
        guard startOffset <= duration else {
            return nil
        }
        
        self.audiobookID = audiobookID
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
            title: self.title,
            audiobookID: self.audiobookID
        )
    }
    public override var description: String {
        return "ChapterLocation P \(self.part) CN \(self.number); PH \(self.playheadOffset) D \(self.duration)"
    }
}
