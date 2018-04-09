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

/// If the AudiobookManager runs into an error while fetching
/// values from the provided Audiobook, it may use this
/// protocol to request a new Audiobook from the host app.
@objc public protocol RefreshDelegate {

    /**
     Will be called when the manager determines it needs a new audiobook.
     
     Example usage:
     ```
     func updateAudiobook(completion: (Audiobook?) -> Void) {
     let audiobook = self.getAudiobook()
     completion(audiobook)
     }
     ```
     
     - Parameters:
        - completion: The block to be called when new audiobook has been obtained.
        - audiobook: The new Audiobook, may be nil if fetch was unsuccessful
     */
    func updateAudiobook(completion: (_ audiobook: Audiobook?) -> Void)
}

/// Conform to this in order to get notifications about download
/// updates from the manager.
@objc public protocol AudiobookManagerDownloadDelegate {
    func audiobookManager(_ audiobookManager: AudiobookManager, didUpdateDownloadPercentageFor spineElement: SpineElement)
    func audiobookManager(_ audiobookManager: AudiobookManager, didBecomeReadyForPlayback spineElement: SpineElement)
    func audiobookManager(_ audiobookManager: AudiobookManager, didReceive error: NSError, for spineElement: SpineElement)
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
    weak var downloadDelegate: AudiobookManagerDownloadDelegate? { get set }
    weak var timerDelegate: AudiobookManagerTimerDelegate? { get set }
    var metadata: AudiobookMetadata { get }
    var audiobook: Audiobook { get }
    var tableOfContents: AudiobookTableOfContents { get }
    var sleepTimer: SleepTimer { get }
    var timer: Timer? { get }
}

/// Implementation of the AudiobookManager intended for use by clients. Also intended
/// to be used by the AudibookDetailViewController to respond to UI events.
public final class DefaultAudiobookManager: AudiobookManager {
    public weak var downloadDelegate: AudiobookManagerDownloadDelegate?
    public weak var timerDelegate: AudiobookManagerTimerDelegate?
    private(set) public var timer: Timer?
    public let metadata: AudiobookMetadata
    public let audiobook: Audiobook
    public var isPlaying: Bool {
        return self.player.isPlaying
    }
    
    public var tableOfContents: AudiobookTableOfContents {
        return AudiobookTableOfContents(
            networkService: self.networkService,
            player: self.player
        )
    }

    /// The SleepTimer may be used to schedule playback to stop at a specific
    /// time. When a sleep timer is scheduled through the `setTimerTo:trigger`
    /// method, it must be retained so that it can properly pause the `player`.
    /// SleepTimer is thread safe, and will block until it can ensure only one
    /// object is messaging it at a time.
    public lazy var sleepTimer: SleepTimer = {
        return SleepTimer(player: self.player)
    }()
    
    private let player: Player
    private let networkService: AudiobookNetworkService
    public init (metadata: AudiobookMetadata, audiobook: Audiobook,  player: Player, networkService: AudiobookNetworkService) {
        self.metadata = metadata
        self.audiobook = audiobook
        self.player = player
        self.networkService = networkService
        self.networkService.registerDelegate(self)
        self.player.registerDelegate(self)
        try? AVAudioSession.sharedInstance().setActive(true)
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
            player: audiobook.player,
            networkService: DefaultAudiobookNetworkService(spine: audiobook.spine)
        )
    }

    @objc func timerDidTick1Second(_ timer: Timer) {
        self.timerDelegate?.audiobookManager(self, didUpdate: timer)
        if let chapter = self.player.currentChapterLocation {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
            if let title = chapter.title {
                info[MPMediaItemPropertyTitle] = title
            }
            info[MPMediaItemPropertyArtist] = self.metadata.title
            info[MPMediaItemPropertyAlbumTitle] = self.metadata.authors.joined(separator: ", ")
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = chapter.playheadOffset
            info[MPMediaItemPropertyPlaybackDuration] = chapter.duration
            info[MPNowPlayingInfoPropertyPlaybackRate] = PlaybackRate.convert(
                rate: self.player.playbackRate
            )
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    weak public var refreshDelegate: RefreshDelegate?
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
            if self.player.isPlaying {
                self.player.pause()
            } else {
                self.player.play()
            }
            return .success
        }
        command.skipForwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.player.skipForward()
            return .success
        }
        command.skipBackwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.player.skipBack()
            return .success
        }
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) { }
    public func player(_ player: Player, didComplete chapter: ChapterLocation) { }
}

extension DefaultAudiobookManager: AudiobookNetworkServiceDelegate {
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError, for spineElement: SpineElement) {
        self.downloadDelegate?.audiobookManager(self, didReceive: error, for: spineElement)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) {
        self.downloadDelegate?.audiobookManager(self, didBecomeReadyForPlayback: spineElement)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement) {
        self.downloadDelegate?.audiobookManager(self, didUpdateDownloadPercentageFor: spineElement)
    }

    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement) { }
}
