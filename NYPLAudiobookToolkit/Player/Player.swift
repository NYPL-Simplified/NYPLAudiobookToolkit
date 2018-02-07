//
//  File.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/31/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import Foundation


/// Receive updates from player as events happen
@objc public protocol PlayerDelegate: class {
    func player(_ player: Player, didBeginPlaybackOf chapter: ChapterDescription)
    func player(_ player: Player, didStopPlaybackOf chapter: ChapterDescription)
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
    func updatePlaybackWith(_ chapter: ChapterDescription)
}

/// *EXPERIMENTAL AND LIKELY TO CHANGE*
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
@objc public protocol ChapterDescription {
    var number: UInt { get }
    var part: UInt { get }
    var duration: TimeInterval { get }
    var offset: TimeInterval { get }
    func chapterWith(_ offset: TimeInterval) -> ChapterDescription
}

class DefaultChapterDescription: ChapterDescription {
    let number: UInt
    let part: UInt
    let duration: TimeInterval
    let offset: TimeInterval

    init(number: UInt, part: UInt, duration: TimeInterval, offset: TimeInterval) {
        self.number = number
        self.part = part
        self.duration = duration
        self.offset = offset
    }

    func chapterWith(_ offset: TimeInterval) -> ChapterDescription {
        return DefaultChapterDescription(
            number: self.number,
            part: self.part,
            duration: self.duration,
            offset: offset
        )
    }
}

/// *EXPERIMENTAL AND LIKELY TO CHANGE*
/// This protocol is supposed to represent how to issue complex commands to the player.
/// IE: stop and seek to 3:00
/// IE: stop and skip to Chapter 3
///
/// The reason this is still experimental is that it likely to duplicate
/// functionality needed by the table of contents. This object will
/// likely need information about seeking between chapters and skipping to
/// new chapters as well.
///
/// This is also likely to change as the interface for doing this with
/// AVPlayer & FAEPlaybackEngine are quite different.
@objc public protocol PlayerCommand {
    /**
     Playhead position in seconds from 0.
    */
    var offset: TimeInterval { get }
    var chapter: ChapterDescription { get }
}

class DefaultPlayerCommand: PlayerCommand {
    let offset: TimeInterval
    let chapter: ChapterDescription
    init(offset: TimeInterval, chapter: ChapterDescription) {
        self.offset = offset
        self.chapter = chapter
    }
}
