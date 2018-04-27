//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine
import MediaPlayer
import AVFoundation

/// If the AudiobookManager runs into an error that may
/// be resolved by fetching a new audiobook manifest from
/// the server, it will request the parent disposes
/// of itself and instantiate a new manager with a new
/// manifest
@objc public protocol RefreshDelegate {

    /**
     Will be called when the manager determines it has reached an error
     that should be resolved by refreshing the AudiobookManager
     */
    func audiobookManagerDidRequestRefresh()
}

@objc public protocol AudiobookManagerTimerDelegate {
    func audiobookManager(_ audiobookManager: AudiobookManager, didUpdate timer: Timer?)
}

/// AudiobookManager is the main class for bringing Audiobook Playback to clients.
/// It is intended to be used by the host app to initiate downloads,
/// access the player, and manage the filesystem.
/// This object also manages the remote playback/media info for control
/// center / airplay.
@objc public protocol AudiobookManager {
    weak var refreshDelegate: RefreshDelegate? { get set }
    weak var timerDelegate: AudiobookManagerTimerDelegate? { get set }
    
    var networkService: AudiobookNetworkService { get}
    var metadata: AudiobookMetadata { get }
    var audiobook: Audiobook { get }
    
    var tableOfContents: AudiobookTableOfContents { get }
    var sleepTimer: SleepTimer { get }

    var timer: Timer? { get }
}

/// Implementation of the AudiobookManager intended for use by clients. Also intended
/// to be used by the AudibookDetailViewController to respond to UI events.
public final class DefaultAudiobookManager: AudiobookManager {
    public weak var timerDelegate: AudiobookManagerTimerDelegate?
    public weak var refreshDelegate: RefreshDelegate?
    
    public let networkService: AudiobookNetworkService
    public let metadata: AudiobookMetadata
    public let audiobook: Audiobook

    public var tableOfContents: AudiobookTableOfContents {
        return AudiobookTableOfContents(
            networkService: self.networkService,
            player: self.audiobook.player
        )
    }

    /// The SleepTimer may be used to schedule playback to stop at a specific
    /// time. When a sleep timer is scheduled through the `setTimerTo:trigger`
    /// method, it must be retained so that it can properly pause the `player`.
    /// SleepTimer is thread safe, and will block until it can ensure only one
    /// object is messaging it at a time.
    public lazy var sleepTimer: SleepTimer = {
        return SleepTimer(player: self.audiobook.player)
    }()

    private(set) public var timer: Timer?
    public init (metadata: AudiobookMetadata, audiobook: Audiobook, networkService: AudiobookNetworkService) {
        self.metadata = metadata
        self.audiobook = audiobook
        self.networkService = networkService
        self.audiobook.player.registerDelegate(self)
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(
                timeInterval: 1,
                target: self,
                selector: #selector(DefaultAudiobookManager.timerDidTick1Second(_:)),
                userInfo: nil,
                repeats: true
            )
        }
    }

    public convenience init (metadata: AudiobookMetadata, audiobook: Audiobook) {
        self.init(
            metadata: metadata,
            audiobook: audiobook,
            networkService: DefaultAudiobookNetworkService(spine: audiobook.spine)
        )
    }

    @objc func timerDidTick1Second(_ timer: Timer) {
        self.timerDelegate?.audiobookManager(self, didUpdate: timer)
        if let chapter = self.audiobook.player.currentChapterLocation {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
            if let title = chapter.title {
                info[MPMediaItemPropertyTitle] = title
            }
            info[MPMediaItemPropertyArtist] = self.metadata.title
            info[MPMediaItemPropertyAlbumTitle] = self.metadata.authors.joined(separator: ", ")
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = chapter.playheadOffset
            info[MPMediaItemPropertyPlaybackDuration] = chapter.duration
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}

extension DefaultAudiobookManager: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        let command = MPRemoteCommandCenter.shared()
        command.togglePlayPauseCommand.isEnabled = true
        command.skipForwardCommand.isEnabled = true
        command.skipBackwardCommand.isEnabled = true
        command.skipForwardCommand.preferredIntervals = [15]
        command.skipBackwardCommand.preferredIntervals = [15]
        
        command.togglePlayPauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            if self.audiobook.player.isPlaying {
                self.audiobook.player.pause()
            } else {
                self.audiobook.player.play()
            }
            return .success
        }
        command.skipForwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.audiobook.player.skipForward()
            return .success
        }
        command.skipBackwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.audiobook.player.skipBack()
            return .success
        }
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) { }
    public func player(_ player: Player, didComplete chapter: ChapterLocation) { }
}
