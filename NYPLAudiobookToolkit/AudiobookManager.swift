//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

@objc public protocol AudiobookManagerDelegate {
    func updateManifest(completion: (AudiobookManifest) -> Void)
}

public protocol AudiobookManagement {
    weak var delegate: AudiobookManagerDelegate? { get set }
    var metadata: AudiobookMetadata { get }
    var manifest: AudiobookManifest { get }
    var isPlaying: Bool { get }
    func fetch()
    func play()
    func pause()
}

public class AudiobookManager: AudiobookManagement {
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
    }

    weak public var delegate: AudiobookManagerDelegate?
    
    public func fetch() {
        self.requester.fetch()
    }

    public func play() {
        
    }
    
    public func pause() {
        
    }
    
}
