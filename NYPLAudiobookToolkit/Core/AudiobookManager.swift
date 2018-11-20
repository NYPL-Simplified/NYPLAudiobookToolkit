//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
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

/// Optionally pass in a function that forwards errors or other notable events
/// above a certain log level in a release build.
public var sharedLogHandler: LogHandler?

/// AudiobookManager is the main class for bringing Audiobook Playback to clients.
/// It is intended to be used by the host app to initiate downloads,
/// access the player, and manage the filesystem.
/// This object also manages the remote playback/media info for control
/// center / airplay.
@objc public protocol AudiobookManager {
    var refreshDelegate: RefreshDelegate? { get set }
    var timerDelegate: AudiobookManagerTimerDelegate? { get set }

    var networkService: AudiobookNetworkService { get }
    var metadata: AudiobookMetadata { get }
    var audiobook: Audiobook { get }

    var tableOfContents: AudiobookTableOfContents { get }
    var sleepTimer: SleepTimer { get }

    var timer: Timer? { get }

    static func setLogHandler(_ handler: @escaping LogHandler)
}

/// Implementation of the AudiobookManager intended for use by clients. Also intended
/// to be used by the AudibookDetailViewController to respond to UI events.
@objcMembers public final class DefaultAudiobookManager: NSObject, AudiobookManager {
    public weak var timerDelegate: AudiobookManagerTimerDelegate?
    public weak var refreshDelegate: RefreshDelegate?
    public var logHandler: LogHandler?

    static private var sharedLogHandler: LogHandler?
    static public func setLogHandler(_ handler: @escaping LogHandler) {
        sharedLogHandler = handler
    }

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
    private let mediaControlHandler: MediaControlHandler
    public init (metadata: AudiobookMetadata, audiobook: Audiobook, networkService: AudiobookNetworkService) {
        self.metadata = metadata
        self.audiobook = audiobook
        self.networkService = networkService
        self.mediaControlHandler = MediaControlHandler(
            togglePlaybackHandler: { (_) -> MPRemoteCommandHandlerStatus in
                if audiobook.player.isPlaying {
                    audiobook.player.pause()
                } else {
                    audiobook.player.play()
                }
                return .success
        }, skipForwardHandler: { (_) -> MPRemoteCommandHandlerStatus in
            audiobook.player.skipPlayhead(SkipTimeInterval, completion: nil)
            return .success
        }, skipBackHandler: { (_) -> MPRemoteCommandHandlerStatus in
            audiobook.player.skipPlayhead(-SkipTimeInterval, completion: nil)
            return .success
        }, playbackRateHandler: { (rateEvent) -> MPRemoteCommandHandlerStatus in
            if let rate = rateEvent as? MPChangePlaybackRateCommandEvent,
            let intRate = PlaybackRate(rawValue: Int(rate.playbackRate * 100)) {
                audiobook.player.playbackRate = intRate
                ATLog(.debug, "Media Control setting Playback Rate: float:\(rate) int:\(intRate)")
                return .success
            } else {
                ATLog(.error, "Media Control failed setting Playback Rate")
                return .commandFailed
            }
        })
        super.init()
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

    deinit {
        ATLog(.debug, "DefaultAudiobookManager is deinitializing.")
    }

    public convenience init(metadata: AudiobookMetadata, audiobook: Audiobook) {
        self.init(
            metadata: metadata,
            audiobook: audiobook,
            networkService: DefaultAudiobookNetworkService(spine: audiobook.spine)
        )
    }

    @objc func timerDidTick1Second(_ timer: Timer) {
        self.timerDelegate?.audiobookManager(self, didUpdate: timer)
        guard self.audiobook.player.isLoaded else { return }
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
        self.mediaControlHandler.enableMediaControlCommands()
    }
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) { }
    public func player(_ player: Player, didComplete chapter: ChapterLocation) { }
    public func playerDidBeginUnload(_ player: Player) {
      self.mediaControlHandler.teardown()
      self.timer?.invalidate()
    }
}

typealias RemoteEventHandler = (_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus

private class MediaControlHandler {

    private var commandsHaveBeenEnabled = false
    private let togglePlaybackHandler: RemoteEventHandler
    private let skipForwardHandler: RemoteEventHandler
    private let skipBackHandler: RemoteEventHandler
    private let playbackRateHandler: RemoteEventHandler
    private var command: MPRemoteCommandCenter {
        return MPRemoteCommandCenter.shared()
    }

    func enableMediaControlCommands() {
        if !self.commandsHaveBeenEnabled {
            self.setMediaControlCommands(enabled: true)
            self.command.skipForwardCommand.preferredIntervals = [15]
            self.command.skipBackwardCommand.preferredIntervals = [15]
            var supportedRates = [NSNumber]()
            PlaybackRate.allCases.forEach {
                let rate = PlaybackRate.convert(rate: $0)
                supportedRates.append(NSNumber(value: rate))
                ATLog(.debug, "Supported playback rate: \(rate)")
            }
            self.command.changePlaybackRateCommand.supportedPlaybackRates = supportedRates

            self.commandsHaveBeenEnabled = true
        }
    }

    func teardown() {
        self.setMediaControlCommands(enabled: false)
        if (MPNowPlayingInfoCenter.default().nowPlayingInfo != nil) {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
        self.command.playCommand.removeTarget(self.togglePlaybackHandler)
        self.command.pauseCommand.removeTarget(self.togglePlaybackHandler)
        self.command.togglePlayPauseCommand.removeTarget(self.togglePlaybackHandler)
        self.command.skipForwardCommand.removeTarget(self.skipForwardHandler)
        self.command.skipBackwardCommand.removeTarget(self.skipBackHandler)
        self.command.changePlaybackRateCommand.removeTarget(self.playbackRateHandler)
    }
    
    init(togglePlaybackHandler: @escaping RemoteEventHandler,
         skipForwardHandler: @escaping RemoteEventHandler,
         skipBackHandler: @escaping RemoteEventHandler,
         playbackRateHandler: @escaping RemoteEventHandler) {
        self.togglePlaybackHandler = togglePlaybackHandler
        self.skipForwardHandler = skipForwardHandler
        self.skipBackHandler = skipBackHandler
        self.playbackRateHandler = playbackRateHandler
        self.command.togglePlayPauseCommand.addTarget(handler: self.togglePlaybackHandler)
        self.command.playCommand.addTarget(handler: self.togglePlaybackHandler)
        self.command.pauseCommand.addTarget(handler: self.togglePlaybackHandler)
        self.command.skipForwardCommand.addTarget(handler: self.skipForwardHandler)
        self.command.skipBackwardCommand.addTarget(handler: self.skipBackHandler)
        self.command.changePlaybackRateCommand.addTarget(handler: self.playbackRateHandler)
    }

    deinit {
        ATLog(.debug, "MediaControlHandler is deinitializing.")
    }

    private func setMediaControlCommands(enabled: Bool) {
        ATLog(.debug, "MediaControlHandler commands toggled to \(enabled)")
        self.command.playCommand.isEnabled = enabled
        self.command.pauseCommand.isEnabled = enabled
        self.command.togglePlayPauseCommand.isEnabled = enabled
        self.command.skipForwardCommand.isEnabled = enabled
        self.command.skipBackwardCommand.isEnabled = enabled
        self.command.changePlaybackRateCommand.isEnabled = enabled
    }
}
