//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc public protocol AudiobookManagerDelegate {
    func updateManifest(completion: (AudiobookManifest) -> Void)
}

protocol AudiobookManagement {
    weak var delegate: AudiobookManagerDelegate? { get set }
    func fetch(metadata: AudiobookMetadata, audiobookManifest: AudiobookManifest)
    func tableOfContents(audiobookID: String) -> AudiobookTableOfContents
    func play(audiobookID: String)
    func pause(audiobookID: String)
}

public class AudiobookManager: AudiobookManagement {
    
    public init () {
        
    }

    weak var delegate: AudiobookManagerDelegate?
    
    func fetch(metadata: AudiobookMetadata, audiobookManifest: AudiobookManifest) {
        
    }
    
    func tableOfContents(audiobookID: String) -> AudiobookTableOfContents {
        return AudiobookTableOfContents()
    }

    func play(audiobookID: String) {
        
    }
    
    func pause(audiobookID: String) {
        
    }
    
}
