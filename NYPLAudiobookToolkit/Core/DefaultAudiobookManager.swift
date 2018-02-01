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
/// values from the provided AudiobookManifest, it may use this
/// protocol to request a new AudiobookManifest from the host app.
@objc public protocol RefreshDelegate {

    /**
     Will be called when the manager determines it needs a new manifest.
     
     Example usage:
     ```
     func updateManifest(completion: (AudiobookManifest?) -> Void) {
     let newManifest = self.getNewManifest()
     completion(newManifest)
     }
     ```
     
     - Parameters:
        - completion: The block to be called when new manifest has been obtained.
        - manifest: The new AudiobookManifest, may be nil if fetch was unsuccessful
     */
    func updateManifest(completion: (_ manifest: Manifest?) -> Void)
}

@objc public protocol AudiobookManagerDelegate {
    func audiobookManager(_ audiobookManager: AudiobookManager, didUpdateDownloadPercentage percentage: Float)
    func audiobookManagerReadyForPlayback(_ audiobookManager: AudiobookManager)
    func audiobookManager(_ audiobookManager: AudiobookManager, didReceive error: AudiobookError)
}

/// AudiobookManager is the main class for bringing Audiobook Playback to clients.
/// It is intended to be used by the host app to initiate downloads, control playback,
/// and manager the filesystem.
@objc public protocol AudiobookManager {
    weak var refreshDelegate: RefreshDelegate? { get set }
    weak var delegate: AudiobookManagerDelegate? { get set }
    var metadata: AudiobookMetadata { get }
    var manifest: Manifest { get }
    var isPlaying: Bool { get }
    func fetch()
    func skipForward()
    func skipBack()
    func play() // needs to take some sort of offset/indication of where to start playing
    func pause()
}

/// Implementation of the AudiobookManager intended for use by clients. Also intended
/// to be used by the AudibookDetailViewController to respond to UI events.
public class DefaultAudiobookManager: AudiobookManager {
    public var delegate: AudiobookManagerDelegate?
    
    public let metadata: AudiobookMetadata
    public let manifest: Manifest
    public var isPlaying: Bool {
        return self.player.isPlaying
    }

    let downloadTask: DownloadTask
    let player: Player

    public init (metadata: AudiobookMetadata, manifest: Manifest, downloadTask: DownloadTask, player: Player) {
        self.metadata = metadata
        self.manifest = manifest
        self.downloadTask = downloadTask
        self.player = player
    }

    public convenience init (metadata: AudiobookMetadata, manifest: Manifest) {
        self.init(metadata: metadata, manifest: manifest, downloadTask: manifest.downloadTask, player: manifest.player)
    }
    
    weak public var refreshDelegate: RefreshDelegate?
    
    public func fetch() {
        self.downloadTask.delegate = self
        self.downloadTask.fetch()
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
}
extension DefaultAudiobookManager: DownloadTaskDelegate {
    public func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookManagerReadyForPlayback(self)
    }
    
    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookManager(self, didUpdateDownloadPercentage: self.downloadTask.downloadProgress )
    }
    
    public func downloadTaskDidError(_ downloadTask: DownloadTask) {
        if let error = downloadTask.error {
            self.delegate?.audiobookManager(self, didReceive: error)
        }
    }
}
