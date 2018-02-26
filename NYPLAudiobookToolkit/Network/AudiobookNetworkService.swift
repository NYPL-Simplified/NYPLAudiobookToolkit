//
//  AudiobookNetworkService.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc public protocol AudiobookNetworkServiceDelegate: class {
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didErrorFor spineElement: SpineElement)
}

@objc public protocol AudiobookNetworkService: class {
    var spine: [SpineElement] { get }
    func fetch()
    func fetchSpineAt(index: Int)
    func deleteAll()
    func registerDelegate(_ delegate: AudiobookNetworkServiceDelegate)
    func removeDelegate(_ delegate: AudiobookNetworkServiceDelegate)
}

public final class DefaultAudiobookNetworkService: AudiobookNetworkService, DownloadTaskDelegate {
    public func downloadTaskDidDeleteAsset(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.delegates.allObjects.forEach { (delegate) in
                delegate.audiobookNetworkService(self, didUpdateDownloadPercentageFor: spineElement)
            }
        }
    }

    private var delegates: NSHashTable<AudiobookNetworkServiceDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])
    
    public func registerDelegate(_ delegate: AudiobookNetworkServiceDelegate) {
        self.delegates.add(delegate)
    }
    
    public func removeDelegate(_ delegate: AudiobookNetworkServiceDelegate) {
        self.delegates.remove(delegate)
    }
    
    public func deleteAll() {
        self.spine.forEach { (spineElement) in
            spineElement.downloadTask.delete()
        }
    }

    public func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.delegates.allObjects.forEach({ (delegate) in
                delegate.audiobookNetworkService(self, didCompleteDownloadFor: spineElement)
            })
        }
    }
    
    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.delegates.allObjects.forEach({ (delegate) in
                delegate.audiobookNetworkService(self, didUpdateDownloadPercentageFor: spineElement)
            })
        }
    }
    
    public func downloadTaskDidError(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.delegates.allObjects.forEach({ (delegate) in
                delegate.audiobookNetworkService(self, didErrorFor: spineElement)
            })
        }
    }
    
    public let spine: [SpineElement]
    lazy var spineElementByKey: [String: SpineElement] = {
        var dict = [String: SpineElement]()
        self.spine.forEach { (element) in
            dict[element.downloadTask.key] = element
        }
        return dict
    }()
    
    public init(spine: [SpineElement]) {
        self.spine = spine
    }
    
    public func fetch() {
        self.spine.forEach { (element) in
            element.downloadTask.delegate = self
            element.downloadTask.fetch()
        }
    }
    
    public func fetchSpineAt(index: Int) {
        let downloadTask = self.spine[index].downloadTask
        downloadTask.delegate = self
        downloadTask.fetch()
    }
}
