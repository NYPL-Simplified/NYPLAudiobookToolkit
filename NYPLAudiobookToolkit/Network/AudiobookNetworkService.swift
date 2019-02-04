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
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateProgressFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateOverallDownloadProgress progress: Float)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError?, for spineElement: SpineElement)
}


/// The protocol for managing the download of chapters. Implementers of
/// this protocol should not be concerned with the details of how
/// the downloads happen or any caching.
///
/// The purpose of an AudiobookNetworkService is to manage the download
/// tasks and tie them back to their spine elements
/// for delegates to consume.
@objc public protocol AudiobookNetworkService: class {
    var spine: [SpineElement] { get }
    var downloadProgress: Float { get }
    
    /// Implementers of this should attempt to download all
    /// spine elements in a serial order. Once the
    /// implementer has begun requesting files, calling this
    /// again should not fire more requests. If no request is
    /// in progress, fetch should always start at the first
    /// spine element.
    ///
    /// Implementations of this should be non-blocking.
    /// Updates for the status of each download task will
    /// come through delegate methods.
    func fetch()
    
    
    /// Implmenters of this should attempt to delete all
    /// spine elements.
    ///
    /// Implementations of this should be non-blocking.
    /// Updates for the status of each download task will
    /// come through delegate methods.
    func deleteAll()
    
    func registerDelegate(_ delegate: AudiobookNetworkServiceDelegate)
    func removeDelegate(_ delegate: AudiobookNetworkServiceDelegate)
}

public final class DefaultAudiobookNetworkService: AudiobookNetworkService {
    public var downloadProgress: Float {
        guard !self.spine.isEmpty else { return 0 }
        let taskCompletedPercentage = self.spine.reduce(0) { (memo: Float, element: SpineElement) -> Float in
            return memo + element.downloadTask.downloadProgress
        }
        ATLog(.debug, "ANS: Overall Download Progress: \(taskCompletedPercentage / Float(self.spine.count))")
        return taskCompletedPercentage / Float(self.spine.count)
    }
    
    private var cursor: Cursor<SpineElement>?
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
    
    public let spine: [SpineElement]
    private var spineElementByKey: [String: SpineElement]
    
    public init(spine: [SpineElement]) {
        self.spine = spine
        self.spineElementByKey = [String: SpineElement]()
        self.spine.forEach { (element) in
            element.downloadTask.delegate = self
            self.spineElementByKey[element.downloadTask.key] = element
        }
    }
    
    public func fetch() {
        if self.cursor == nil {
            self.cursor = Cursor(data: self.spine)
        }
        self.cursor?.currentElement.downloadTask.fetch()
    }
}

extension DefaultAudiobookNetworkService: DownloadTaskDelegate {
    public func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
        self.cursor = self.cursor?.next()
        self.cursor?.currentElement.downloadTask.fetch()
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesThatPlaybackIsReadyFor(spineElement)
            }
        }
    }

    public func downloadTaskDidDeleteAsset(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesOfDeleteFor(spineElement)
            }
        }
    }

    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesOfDownloadPercentFor(spineElement)
            }
        }
    }

    public func downloadTaskFailed(_ downloadTask: DownloadTask, withError error: NSError?) {
        self.cursor = nil
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesThatErrorWasReceivedFor(spineElement, error: error)
            }
        }
    }

    func notifyDelegatesThatPlaybackIsReadyFor(_ spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didCompleteDownloadFor: spineElement)
            delegate.audiobookNetworkService(self, didUpdateOverallDownloadProgress: self.downloadProgress)
        }
    }

    func notifyDelegatesOfDownloadPercentFor(_ spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didUpdateProgressFor: spineElement)
            delegate.audiobookNetworkService(self, didUpdateOverallDownloadProgress: self.downloadProgress)
        }
    }

    func notifyDelegatesThatErrorWasReceivedFor(_ spineElement: SpineElement, error: NSError?) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didReceive: error, for: spineElement)
        }
    }
    
    func notifyDelegatesOfDeleteFor(_ spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didDeleteFileFor: spineElement)
        }
    }
}
