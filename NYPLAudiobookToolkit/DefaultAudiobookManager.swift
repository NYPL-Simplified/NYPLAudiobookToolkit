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
    func updateManifest(completion: (_ manifest: AudiobookManifest?) -> Void)
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
    var manifest: AudiobookManifest { get }
    var isPlaying: Bool { get }
    func fetch()
    func play() // needs to take some sort of offset/indication of where to start playing
    func pause()
}

/// Implementation of the AudiobookManager intended for use by clients. Also intended
/// to be used by the AudibookDetailViewController to respond to UI events.
public class DefaultAudiobookManager: AudiobookManager {
    
    public var delegate: AudiobookManagerDelegate?
    
    public let metadata: AudiobookMetadata
    public let manifest: AudiobookManifest
    public var isPlaying: Bool {
        return true
    }

    let requester: AudiobookNetworkRequester

    public init (metadata: AudiobookMetadata, manifest: AudiobookManifest, requester: AudiobookNetworkRequester) {
        self.metadata = metadata
        self.manifest = manifest
        self.requester = requester
    }
    
    public convenience init (metadata: AudiobookMetadata, manifest: AudiobookManifest) {
        let requester = AudiobookNetworkService(manifest: manifest)
        self.init(metadata: metadata, manifest: manifest, requester: requester)
        requester.delegate = self
    }

    weak public var refreshDelegate: RefreshDelegate?
    
    public func fetch() {
        self.requester.fetch()
    }

    public func play() {
        
    }
    
    public func pause() {
        
    }
}

extension DefaultAudiobookManager: AudiobookNetworkRequesterDelegate {
    public func audiobookNetworkServiceDidUpdateProgress(_ audiobookNetworkService: AudiobookNetworkService) {
        self.delegate?.audiobookManager(self, didUpdateDownloadPercentage: self.requester.downloadProgress)
    }
    
    public func audiobookNetworkServiceDidError(_ audiobookNetworkService: AudiobookNetworkService) {
        if let error = audiobookNetworkService.error {
            self.delegate?.audiobookManager(self, didReceive: error)
        }
    }
    
    public func audiobookNetworkServiceReadyForPlayback(_ audiobookNetworkService: AudiobookNetworkService) {
        self.delegate?.audiobookManagerReadyForPlayback(self)
    }
}
