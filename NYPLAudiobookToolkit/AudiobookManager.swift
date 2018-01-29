//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

@objc public protocol RefreshDelegate {
    func updateManifest(completion: (AudiobookManifest) -> Void)
}

@objc public protocol AudiobookManagementDelegate {
    func audiobookManager(_ AudiobookManagment: AudiobookManagement, didUpdateDownloadPercentage percentage: Float)
    func audiobookManagerReadyForPlayback(_ AudiobookManagment: AudiobookManagement)
    func audiobookManager(_ AudiobookManagment: AudiobookManagement, didRecieve error: AudiobookError)
}

@objc public protocol AudiobookManagement {
    weak var refreshDelegate: RefreshDelegate? { get set }
    weak var delegate: AudiobookManagementDelegate? { get set }
    var metadata: AudiobookMetadata { get }
    var manifest: AudiobookManifest { get }
    var isPlaying: Bool { get }
    func fetch()
    func play() // needs to take some sort of offset/indication of where to start playing
    func pause()
}

public class AudiobookManager: AudiobookManagement {
    
    public var delegate: AudiobookManagementDelegate?
    
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

extension AudiobookManager: AudiobookNetworkRequesterDelegate {
    public func audiobookNetworkServiceDidUpdateProgress(_ audiobookNetworkService: AudiobookNetworkService) {
        self.delegate?.audiobookManager(self, didUpdateDownloadPercentage: self.requester.downloadProgress)
    }
    
    public func audiobookNetworkServiceDidError(_ audiobookNetworkService: AudiobookNetworkService) {
        if let error = audiobookNetworkService.error {
            self.delegate?.audiobookManager(self, didRecieve: error)
        }
    }
    
    public func audiobookNetworkServiceReadyForPlayback(_ audiobookNetworkService: AudiobookNetworkService) {
        self.delegate?.audiobookManagerReadyForPlayback(self)
    }
}
