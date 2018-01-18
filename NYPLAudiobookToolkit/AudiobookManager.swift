//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc public protocol Refreshable {
    func updateManifest(completion: (AudiobookManifest) -> Void)
}

public class AudiobookManager: NSObject {
    public func fetchAudiobook(metadata: AudiobookMetadata, audiobookManifest: AudiobookManifest, refreshDelegate: Refreshable) {
    }
}
