import Foundation

@objc public enum PlaybackRate: Int, CaseIterable {
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
@objc public protocol PlayerDelegate: AnyObject {

    /// Guaranteed to be called on the following scenarios:
    ///   * The playhead crossed to a new chapter
    ///   * The play() method was called
    ///   * The playhead was modified, the result of jumpToLocation(_), skipForward() or skipBack()
    func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation)

    /// Called to notify that playback has stopped
    /// this should only happen as a result of pause() being called.
    func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation)

    /// Playback failed. Send an error with more context if it is available.
    func player(_ player: Player, didFailPlaybackOf chapter: ChapterLocation, withError error: NSError?)

    /// Called when the playhead crosses a chapter boundary without direction.
    /// Depending on the underlying playback engine, this could come some time
    /// after the next chapter has begun playing. This should arrive before
    /// `player:didBeginPlaybackOf:` is called.
    func player(_ player: Player, didComplete chapter: ChapterLocation)

    /// Called by the host when we're done with the audiobook, to perform necessary cleanup.
    func playerDidUnload(_ player: Player)
}

/// Objects that impelment Player should wrap a PlaybackEngine.
/// This does not specifically refer to AVPlayer, but could also be
/// FAEPlaybackEngine, or another engine that handles DRM content.
@objc public protocol Player {
    var isPlaying: Bool { get }
    
    // When set, should lock down playback
    var isDrmOk: Bool { get set }
    
    var currentChapterLocation: ChapterLocation? { get }

    /// The rate at which the audio will play, when playing.
    var playbackRate: PlaybackRate { get set }
    
    /// `false` after `unload` is called, else `true`.
    var isLoaded: Bool { get }
    
    /// Play at current playhead location
    func play()
    
    /// Pause playback
    func pause()
  
    /// End playback and free resources; the `Player` is not expected to be
    /// usable after this method is called
    func unload()
    
    /// Skip forward or backward with the desired interval in seconds,
    /// returns the actual time interval delivered to the Player.
    func skipPlayhead(_ timeInterval: TimeInterval, completion: ((ChapterLocation)->())?) -> ()

    /// Move playhead to specific chapter location
    /// This method is useful for scenarios like
    /// 1. navigating to a chapter from table of contents
    /// 2. navigating to a bookmark location
    /// 3. restoring last listened position
    /// Pass `true` to `shouldBeginAutoPlay` to begin playback immediately
    /// if the player is paused and ready to play.
    func movePlayhead(to location: ChapterLocation, shouldBeginAutoPlay: Bool)

    func registerDelegate(_ delegate: PlayerDelegate)
    func removeDelegate(_ delegate: PlayerDelegate)
}

/// This class represents a location in a book.
@objcMembers public final class ChapterLocation: NSObject, Comparable, Codable {
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
  
    public convenience init?(from bookmark: NYPLAudiobookBookmark) {
      self.init(number: bookmark.chapter,
                part: bookmark.part,
                duration: bookmark.duration,
                startOffset: 0,
                playheadOffset: bookmark.time,
                title: bookmark.title,
                audiobookID: bookmark.audiobookId)
    }

    public func update(playheadOffset offset: TimeInterval) -> ChapterLocation? {
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
    
    public func toData() -> Data {
        return try! JSONEncoder().encode(self)
    }
    
    public class func fromData(_ data: Data) -> ChapterLocation? {
        return try? JSONDecoder().decode(ChapterLocation.self, from: data)
    }

    public static func < (lhs: ChapterLocation, rhs: ChapterLocation) -> Bool {
        if lhs.part != rhs.part {
            return lhs.part < rhs.part
        } else if lhs.number != rhs.number {
            return lhs.number < rhs.number
        } else {
            return lhs.playheadOffset < rhs.playheadOffset
        }
    }
}

public typealias Playhead = (location: ChapterLocation, cursor: Cursor<SpineElement>)

/// Utility function for manipulating the playhead.
///
/// We navigate around audiobooks using `ChapterLocation` objects that represent
/// some section of audio that the player can navigate to.
///
/// We seek through chapters by calling the `chapterWith(_ offset:)` method on
/// the `currentChapterLocation` to create a new `ChapterLocation` with an
/// offset pointing to the passed in `offset`.
///
/// It is possible the new `offset` is not located in the `ChapterLocation` it
/// represents. For example, if the new `offset` is longer than the duration of
/// the chapter. The `moveTo(to:cursor:)` function resolves such conflicts and
/// returns a `Playhead` containing the correct chapter location for a Player to
/// use.
///
/// For example, if you have 5 seconds left in a chapter and you go to skip
/// ahead 15 seconds. This chapter will return a `Playhead` where the `location`
/// is 10 seconds into the next chapter and a `cursor` that points to the new
/// playhead.
///
/// - Parameters:
///   - destination: The `ChapterLocation` we are navigating to. This
///     destination has a playhead that may or may not be inside the chapter it
///     represents.
///   - cursor: The `Cursor` representing the spine for that book.
/// - Returns: The `Playhead` where the location represents the chapter the
///   playhead is located in, and a cursor that points to that chapter.
public func move(cursor: Cursor<SpineElement>, to destination: ChapterLocation) -> Playhead {

    // Check if location is in immediately adjacent chapters
    if let nextPlayhead = attemptToMove(cursor: cursor, forwardTo: destination) {
        return nextPlayhead
    } else if let prevPlayhead = attemptToMove(cursor: cursor, backTo: destination) {
        return prevPlayhead
    }

    // If not, locate the spine index containing the location
    var foundIndex: Int? = nil
    for (i, element) in cursor.data.enumerated() {
        if element.chapter.number == destination.number {
            foundIndex = i
            break
        }
    }
    if let foundIndex = foundIndex {
        let cursor = Cursor(data: cursor.data, index: foundIndex)!
        return (destination, cursor)
    } else {
        ATLog(.error, "Cursor move failure. Returning original cursor.")
        return (cursor.currentElement.chapter, cursor)
    }
}

/// For special UX consideration, many types of skips may not actually be
/// intended to move at the original requested duration.
///
/// - Parameters:
///   - currentOffset: Current playhead offset of the current spine element / chapter
///   - chapterDuration: Full duration of the spine element / chapter (end of scrubber)
///   - skipTime: The requested skip time interval
/// - Returns: The new Playhead Offset location that should be set
public func adjustedPlayheadOffset(currentPlayheadOffset currentOffset: TimeInterval,
                                   currentChapterDuration chapterDuration: TimeInterval,
                                   requestedSkipDuration skipTime: TimeInterval) -> TimeInterval {
    let requestedPlayheadOffset = currentOffset + skipTime
    if (currentOffset == chapterDuration) {
        return requestedPlayheadOffset
    } else if (skipTime > 0) {
        return min(requestedPlayheadOffset, chapterDuration)
    } else {
        if currentOffset > abs(skipTime) {
            return requestedPlayheadOffset
        } else if requestedPlayheadOffset > (skipTime + 4) {
            return 0
        } else {
            return skipTime
        }
    }
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

    // Same chapter, but playhead offset is beyond upper bound
    guard let timeIntoNextChapter = location.timeIntoNextChapter else { return nil }
    var possibleDestinationLocation: ChapterLocation?

    let newCursor: Cursor<SpineElement>
    if let nextCursor = cursor.next() {
        let newChapter = chapterAt(cursor: nextCursor)
        if newChapter.duration > timeIntoNextChapter {
            possibleDestinationLocation = newChapter.update(
                playheadOffset: timeIntoNextChapter
            )
        } else {
            possibleDestinationLocation = newChapter
        }
        newCursor = nextCursor
    } else {
        // No chapter exists after the current one
        possibleDestinationLocation = chapterAt(cursor: cursor).update(
            playheadOffset: chapterAt(cursor: cursor).duration
        )
        newCursor = cursor
    }
    return playhead(location: possibleDestinationLocation, cursor: newCursor)
}

private func attemptToMove(cursor: Cursor<SpineElement>, backTo location: ChapterLocation) -> Playhead?  {

    // Same chapter, but playhead offset is below lower bound
    guard let timeIntoPreviousChapter = location.secondsBeforeStart else {
        debugPrint("No negative time detected.")
        return nil
    }
    var possibleDestinationLocation: ChapterLocation?

    let newCursor: Cursor<SpineElement>
    if let prevCursor = cursor.prev() {
        newCursor = prevCursor
        let destinationChapter = chapterAt(cursor: newCursor)
        let playheadOffset = destinationChapter.duration - timeIntoPreviousChapter
        possibleDestinationLocation = destinationChapter.update(playheadOffset: max(0, playheadOffset))
    } else {
        // No chapter exists before the current one
        possibleDestinationLocation = chapterAt(cursor: cursor).update(playheadOffset: 0)
        newCursor = cursor
    }
    return playhead(location: possibleDestinationLocation, cursor: newCursor)
}


