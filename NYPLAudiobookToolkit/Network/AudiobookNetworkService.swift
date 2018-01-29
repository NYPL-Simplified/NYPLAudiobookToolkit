//
//  AudiobookNetworkRequest.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit


@objc public protocol AudiobookNetworkRequesterDelegate: class {
    func audiobookNetworkServiceDidUpdateProgress(_ audiobookNetworkService: AudiobookNetworkService)
    func audiobookNetworkServiceReadyForPlayback(_ audiobookNetworkService: AudiobookNetworkService)
    func audiobookNetworkServiceDidError(_ audiobookNetworkService: AudiobookNetworkService)
}

@objc public protocol AudiobookNetworkRequester: class {
    func fetch()
    var downloadProgress: Float { get }
    var manifest: AudiobookManifest { get }
    var delegate: AudiobookNetworkRequesterDelegate? { get set }
    var error: AudiobookError? { get }
}

public class AudiobookNetworkService: NSObject, AudiobookNetworkRequester {
    public let manifest: AudiobookManifest
    public weak var delegate: AudiobookNetworkRequesterDelegate?
    
    public var error: AudiobookError? {
        return self.downloadTask?.error
    }
    
    public var downloadProgress: Float {
        return self.downloadTask?.downloadProgress ?? 0.0
    }

    private var downloadTask: DownloadTask?

    internal init(manifest: AudiobookManifest, downloadTask: DownloadTask?) {
        self.manifest = manifest
        self.downloadTask = downloadTask
    }
    
    convenience init(manifest: AudiobookManifest) {
        var downloadTask: DownloadTask? = nil
        switch manifest.spine {
        case .findaway(let spine):
             downloadTask = FindawayDownloadTask(spine: spine)
        // TODO: Implement HTTP Fragments
        case .http(let _):
            print("Requires a different spine")
        }
        self.init(manifest: manifest, downloadTask: downloadTask)
    }

    public func fetch() {
        self.downloadTask?.delegate = self
        self.downloadTask?.fetch()
    }
}

extension AudiobookNetworkService: DownloadTaskDelegate {
    func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookNetworkServiceDidUpdateProgress(self)
    }
    
    func downloadTaskDidError(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookNetworkServiceDidError(self)
    }
    
    func downloadTaskReadyForPlayback(_ readyForPlayback: DownloadTask) {
        self.delegate?.audiobookNetworkServiceReadyForPlayback(self)
    }
}
