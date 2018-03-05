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
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError, for spineElement: SpineElement)
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
    var downloadPercentage: Float { get }
    
    /// Implmenters of this should attempt to download all
    /// spine elements.
    ///
    /// Updates for the status of each download task will
    /// come through delegate methods.
    func fetch()
    
    /// Implmenters of this should attempt to download spine
    /// elements at the requested index.
    ///
    /// Updates for the status of this download task will
    /// come through delegate methods.
    func fetchSpineAt(index: Int)
    
    
    /// Implmenters of this should attempt to delete all
    /// spine elements.
    ///
    /// Updates for the status of each download task will
    /// come through delegate methods.
    func deleteAll()
    
    func registerDelegate(_ delegate: AudiobookNetworkServiceDelegate)
    func removeDelegate(_ delegate: AudiobookNetworkServiceDelegate)
}

public final class DefaultAudiobookNetworkService: AudiobookNetworkService {
    public var downloadPercentage: Float {
        guard !self.spine.isEmpty else { return 0 }
        let taskCompletedPercentage = self.spine.reduce(0) { (memo: Float, element: SpineElement) -> Float in
            return memo + element.downloadTask.downloadProgress
        }
        return taskCompletedPercentage / Float(self.spine.count)
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
    
    public let spine: [SpineElement]
    private lazy var spineElementByKey: [String: SpineElement] = {
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

extension DefaultAudiobookNetworkService: DownloadTaskDelegate {
    public func downloadTask(_ downloadTask: DownloadTask, didReceive error: NSError) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesThatErrorWasReceivedFor(spineElement, error: error)
            }
        }
    }

    func notifyDelegatesThatErrorWasReceivedFor(_ spineElement: SpineElement, error: NSError) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didReceive: error, for: spineElement)
        }
    }
    
    public func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesThatPlaybackIsReadyFor(spineElement)
            }
        }
    }
    
    func notifyDelegatesThatPlaybackIsReadyFor(_ spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didCompleteDownloadFor: spineElement)
        }
    }

    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesOfDownloadPercentFor(spineElement)
            }
        }
    }
    
    func notifyDelegatesOfDownloadPercentFor(_ spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didUpdateDownloadPercentageFor: spineElement)
        }
    }

    public func downloadTaskDidDeleteAsset(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesOfDeleteFor(spineElement)
            }
        }
    }
    
    func notifyDelegatesOfDeleteFor(_ spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didDeleteFileFor: spineElement)
        }
    }
}
