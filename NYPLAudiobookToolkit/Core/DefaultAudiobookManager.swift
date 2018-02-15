//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

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

@objc public protocol AudiobookManagerDownloadDelegate {
    func audiobookManager(_ audiobookManager: AudiobookManager, didUpdateDownloadPercentage percentage: Float)
    func audiobookManagerReadyForPlayback(_ audiobookManager: AudiobookManager)
    func audiobookManager(_ audiobookManager: AudiobookManager, didReceive error: AudiobookError)
}

@objc public protocol AudiobookManagerPlaybackDelegate {
    func audiobookManager(_ audiobookManager: AudiobookManager, didBeginPlaybackOf chapter: ChapterLocation)
    func audiobookManager(_ audiobookManager: AudiobookManager, didStopPlaybackOf chapter: ChapterLocation)
}

/// AudiobookManager is the main class for bringing Audiobook Playback to clients.
/// It is intended to be used by the host app to initiate downloads, control playback,
/// and manage the filesystem.
@objc public protocol AudiobookManager {
    weak var refreshDelegate: RefreshDelegate? { get set }
    weak var downloadDelegate: AudiobookManagerDownloadDelegate? { get set }
    weak var playbackDelegate: AudiobookManagerPlaybackDelegate? { get set }
    var metadata: AudiobookMetadata { get }
    var audiobook: Audiobook { get }
    var isPlaying: Bool { get }
    func fetch()
    func skipForward()
    func skipBack()
    func play()
    func pause()
    func updatePlaybackWith(_ chapter: ChapterLocation)
}

/// Implementation of the AudiobookManager intended for use by clients. Also intended
/// to be used by the AudibookDetailViewController to respond to UI events.
public class DefaultAudiobookManager: AudiobookManager {
    public weak var downloadDelegate: AudiobookManagerDownloadDelegate?
    public weak var playbackDelegate: AudiobookManagerPlaybackDelegate?
    public let metadata: AudiobookMetadata
    public let audiobook: Audiobook
    public var isPlaying: Bool {
        return self.player.isPlaying
    }

    let player: Player
    public init (metadata: AudiobookMetadata, audiobook: Audiobook,  player: Player) {
        self.metadata = metadata
        self.audiobook = audiobook
        self.player = player


        self.player.delegate = self
    }

    public convenience init (metadata: AudiobookMetadata, audiobook: Audiobook) {
        self.init(
            metadata: metadata,
            audiobook: audiobook,
            player: audiobook.player
        )
    }
    
    weak public var refreshDelegate: RefreshDelegate?
    
    public func fetch() {
    }

    public func play() {
        self.player.play()
    }
    
    public func pause() {
        self.player.pause()
    }

    public func skipForward() {
        self.player.skipForward()
    }
    
    public func skipBack() {
        self.player.skipBack()
    }
    
    public func updatePlaybackWith(_ chapter: ChapterLocation) {
        self.player.jumpToChapter(chapter)
    }
}

extension DefaultAudiobookManager: DownloadTaskDelegate {
    public func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
//        DispatchQueue.main.async { [weak self] in
//            if let strongSelf = self {
//                strongSelf.downloadDelegate?.audiobookManagerReadyForPlayback(strongSelf)
//            }
//        }
    }
    
    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
//        DispatchQueue.main.async { [weak self] in
//            if let strongSelf = self {
//                strongSelf.downloadDelegate?.audiobookManager(strongSelf, didUpdateDownloadPercentage: strongSelf.downloadTask.downloadProgress)
//            }
//        }
    }
    
    public func downloadTaskDidError(_ downloadTask: DownloadTask) {
        guard downloadTask.error != nil else { return }
//        DispatchQueue.main.async { [weak self] in
//            if let strongSelf = self {
//                if let error = downloadTask.error {
//                    strongSelf.downloadDelegate?.audiobookManager(strongSelf, didReceive: error)
//                }
//            }
//        }
    }
}

extension DefaultAudiobookManager: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.playbackDelegate?.audiobookManager(strongSelf, didBeginPlaybackOf: chapter)
            }
        }
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.playbackDelegate?.audiobookManager(strongSelf, didStopPlaybackOf: chapter)
            }
        }
    }
}
