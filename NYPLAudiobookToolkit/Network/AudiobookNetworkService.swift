//
//  AudiobookNetworkRequest.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//
import UIKit

/// Notifications about the status of the download.
@objc public protocol AudiobookNetworkRequesterDelegate: class {
    func audiobookNetworkServiceDidUpdateProgress(_ audiobookNetworkService: AudiobookNetworkService)
    func audiobookNetworkServiceReadyForPlayback(_ audiobookNetworkService: AudiobookNetworkService)
    func audiobookNetworkServiceDidError(_ audiobookNetworkService: AudiobookNetworkService)
}

/// Implementers of this protocol should be able to perform network operations
/// for a given AudiobookManifest. Implementers of this protocol would best
/// be served by delegating work to implementers of the DownloadTask protocol.
@objc public protocol AudiobookNetworkRequester: class {
    func fetch()
    var downloadProgress: Float { get }
    var manifest: Manifest { get }
    weak var delegate: AudiobookNetworkRequesterDelegate? { get set }
    var error: AudiobookError? { get }
}


public class AudiobookNetworkService: NSObject, AudiobookNetworkRequester {
    public let manifest: Manifest
    public weak var delegate: AudiobookNetworkRequesterDelegate?
    
    public var error: AudiobookError? {
        return self.downloadTask?.error
    }
    
    public var downloadProgress: Float {
        return self.downloadTask?.downloadProgress ?? 0.0
    }

    private var downloadTask: DownloadTask?

    internal init(manifest: Manifest, downloadTask: DownloadTask?) {
        self.manifest = manifest
        self.downloadTask = downloadTask
    }

    convenience init(manifest: Manifest) {
        self.init(manifest: manifest, downloadTask: manifest.downloadTask)
    }

    public func fetch() {
        self.downloadTask?.delegate = self
        self.downloadTask?.fetch()
    }
}

extension AudiobookNetworkService: DownloadTaskDelegate {
    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookNetworkServiceDidUpdateProgress(self)
    }
    
    public func downloadTaskDidError(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookNetworkServiceDidError(self)
    }
    
    public func downloadTaskReadyForPlayback(_ readyForPlayback: DownloadTask) {
        self.delegate?.audiobookNetworkServiceReadyForPlayback(self)
    }
}
