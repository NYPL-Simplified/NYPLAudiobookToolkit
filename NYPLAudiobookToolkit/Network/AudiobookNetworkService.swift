//
//  AudiobookNetworkRequest.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

public protocol AudiobookNetworkRequesterDelegate: class {
    func audiobookNetworkServiceDidUpdateProgress(_ audiobookNetworkService: AudiobookNetworkService)
    func audiobookNetworkServiceDidCompleteDownload(_ audiobookNetworkService: AudiobookNetworkService)
}

public protocol AudiobookNetworkRequester: class {
    func fetch()
    var downloadProgress: Int { get }
    var manifest: AudiobookManifest { get }
    var delegate: AudiobookNetworkRequesterDelegate? { get set }
}

public class AudiobookNetworkService: NSObject, AudiobookNetworkRequester, DownloadTaskDelegate {
    
    public let manifest: AudiobookManifest

    private var downloadTask: DownloadTask?

    public var downloadProgress: Int {
        return self.downloadTask?.downloadProgress ?? 0
    }
    
    public init(manifest: AudiobookManifest) {
        self.manifest = manifest
        switch self.manifest.spine {
        case .findaway(let spine):
            self.downloadTask = FindawayDownloadTask(spine: spine)
        case .http(let spine):
            print("Requires a different spine")
        }
    }
    
    weak public var delegate: AudiobookNetworkRequesterDelegate?

    public func fetch() {
        self.downloadTask?.delegate = self
        self.downloadTask?.fetch()
    }

    func downloadTaskDidComplete(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookNetworkServiceDidCompleteDownload(self)
    }
    
    func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        self.delegate?.audiobookNetworkServiceDidUpdateProgress(self)
    }
}
