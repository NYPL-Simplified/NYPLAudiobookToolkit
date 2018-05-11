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
    
    public static func convert(rate: PlaybackRate) -> Float {
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
    var isPlaying: Bool { get }
    var currentChapterLocation: ChapterLocation? { get }
    var playbackRate: PlaybackRate { get set }
    
    /// Play at current playhead location
    func play()
    
    /// Pause playback
    func pause()
    
    /// Skip forward 15 seconds and start playback
    func skipForward()

    /// Skip back 15 seconds and start playback
    func skipBack()
    
    /// Move playhead and immediately start playing
    /// This method is useful for scenarios like a table of contents
    /// where you select a new chapter and wish to immediately start
    /// playback.
    func playAtLocation(_ location: ChapterLocation)
    
    /// Move playhead but do not start playback. This is useful for
    /// state restoration where we want to prepare for playback
    /// at a specific point, but playback has not yet been requested.
    func movePlayheadToLocation(_ location: ChapterLocation)

    func registerDelegate(_ delegate: PlayerDelegate)
    func removeDelegate(_ delegate: PlayerDelegate)
}

/// This class represents a location in a book.
@objcMembers public final class ChapterLocation: NSObject, Codable {
    public let title: String?
    public let number: UInt
    public let part: UInt
    public let duration: TimeInterval
    public let startOffset: TimeInterval
    public let playheadOffset: TimeInterval
    public let audiobookID: String

    public var timeRemaining: TimeInterval {
        return self.duration - self.playheadOffset
    }

    public var secondsBeforeStart: TimeInterval? {
        var timeInterval: TimeInterval? = nil
        if self.playheadOffset < 0 {
            timeInterval = abs(self.playheadOffset)
        }
        return timeInterval
    }
    
    public var timeIntoNextChapter: TimeInterval? {
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

    public func chapterWith(_ offset: TimeInterval) -> ChapterLocation? {
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

public typealias Playhead = (location: ChapterLocation, cursor: Cursor<SpineElement>)

/// Utility function for manipulating the playhead.
///
/// We navigate around audiobooks using `ChapterLocation` objects that represent
/// some section of audio that the player can navigate to.
///
/// We seek through chapters by calling the `chapterWith(_ offset:)` method
/// on the `currentChapterLocation` to create a new `ChapterLocation` with an offset pointing to the passed
/// in `offset`.
///
/// It is possible the new `offset` is not located in the `ChapterLocation` it represents.
/// For example, if the new `offset` is longer than the duration of the chapter.
/// The `moveTo(to:cursor:)` function resolves such conflicts and returns a `Playhead` containing
/// the correct chapter location for a Player to use.
///
/// For example, if you have 5 seconds left in a chapter and you go to skip
/// ahead 15 seconds. This chapter will return a `Playhead` where the `location`
/// is 10 seconds into the next chapter and a `cursor` that points to the new playhead.
///
/// If the `destination` passed in is within the `cursor`’s current chapter, then the `Playhead`
/// consists of the arguments passed in.
///
/// - Parameters:
///   - destination: The `ChapterLocation` we are navigating to. This destination has a playhead that may or may not be inside the chapter it represents.
///   - cursor: The `Cursor` representing the spine for that book.
/// - Returns:
///  The `Playhead` where the location represents the chapter the playhead is located in, and a cursor that points to that chapter.
public func move(cursor: Cursor<SpineElement>, to destination: ChapterLocation) -> Playhead {
    let newPlayhead: Playhead
    // Check to see if our playback location is in the next chapter
    if let nextPlayhead = attemptToMove(cursor: cursor, forwardTo: destination) {
        newPlayhead = nextPlayhead
    // Check if playback location is in the previous chapter
    } else if let prevPlayhead = attemptToMove(cursor: cursor, backTo: destination) {
        newPlayhead = prevPlayhead
    // We are already in the correct chapter. Pass the playhead on as is.
    } else {
        newPlayhead = (location: destination, cursor: cursor)
    }

    return newPlayhead
}

private func chapterAt(cursor: Cursor<SpineElement>) -> ChapterLocation {
    return cursor.currentElement.chapter
}

private func playhead(location: ChapterLocation?, cursor: Cursor<SpineElement>?) -> Playhead? {
    guard let location = location else { return nil }
    guard let cursor = cursor else { return nil }
    return (location: location, cursor: cursor)
}

private func attemptToMove(cursor: Cursor<SpineElement>, forwardTo location: ChapterLocation) -> Playhead? {
    // Only if the time points into the next chapter should we try to move the cursor forward.
    guard let timeIntoNextChapter = location.timeIntoNextChapter else { return nil }
    var possibleDestinationLocation: ChapterLocation?
    // Attempt to move the cursor forward indicating
    // there is a next chapter for us to play.
    let newCursor: Cursor<SpineElement>
    if let nextCursor = cursor.next() {
        let newChapter = chapterAt(cursor: nextCursor)
        // If the new chapter is too short to skip to the current point,
        // we go to the start of that chapter.
        if newChapter.duration > timeIntoNextChapter {
            possibleDestinationLocation = newChapter.chapterWith(
                timeIntoNextChapter
            )
        } else {
            possibleDestinationLocation = newChapter
        }

        newCursor = nextCursor
    } else {
        // If there is no next chapter, then we are at the end of the book
        // and we skip to the end.
        possibleDestinationLocation = chapterAt(cursor: cursor).chapterWith(
            chapterAt(cursor: cursor).duration
        )
        newCursor = cursor
    }
    return playhead(location: possibleDestinationLocation, cursor: newCursor)
}

private func attemptToMove(cursor: Cursor<SpineElement>, backTo location: ChapterLocation) -> Playhead?  {
    // Only if the time points into the last chapter should we try to move the cursor back.
    guard let timeIntoPreviousChapter = location.secondsBeforeStart else { return nil }
    var possibleDestinationLocation: ChapterLocation?
    // Attempt to move the cursor backwards indicating
    // there is a previous chapter for us to play.
    let newCursor: Cursor<SpineElement>
    if let prevCursor = cursor.prev() {
        newCursor = prevCursor
        let destinationChapter = chapterAt(cursor: newCursor)
        let playheadOffset = destinationChapter.duration - timeIntoPreviousChapter
        possibleDestinationLocation = destinationChapter.chapterWith(max(0, playheadOffset))
    } else {
        // If there is no previous chapter, we are at the start of the book
        // and skip to the beginning.
        possibleDestinationLocation = chapterAt(cursor: cursor).chapterWith(0)
        newCursor = cursor
    }
    return playhead(location: possibleDestinationLocation, cursor: newCursor)
}
