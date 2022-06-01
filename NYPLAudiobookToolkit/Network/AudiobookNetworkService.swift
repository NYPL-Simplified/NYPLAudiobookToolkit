//
//  AudiobookNetworkService.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLUtilities
import NYPLUtilitiesObjc

@objc public protocol AudiobookNetworkServiceDelegate: AnyObject {
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateProgressFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateOverallDownloadProgress progress: Float)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError?, for spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                 didTimeoutFor spineElement: SpineElement?,
                                 networkStatus: NetworkStatus)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                 downloadExceededTimeLimitFor spineElement: SpineElement,
                                 elapsedTime: TimeInterval,
                                 networkStatus: NetworkStatus)
}


/// The protocol for managing the download of chapters. Implementers of
/// this protocol should not be concerned with the details of how
/// the downloads happen or any caching.
///
/// The purpose of an AudiobookNetworkService is to manage the download
/// tasks and tie them back to their spine elements
/// for delegates to consume.
@objc public protocol AudiobookNetworkService: AnyObject {
    var spine: [SpineElement] { get }
    var downloadProgress: Float { get }
    var downloadCompleted: Bool { get }
    var isDownloading: Bool { get }
    
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
    
    func cancelFetch()
    
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
    private var timeoutTimer: NYPLRepeatingTimer?
    private var reachabilityManager: ReachabilityManager?
  
    var lastProgressUpdate: (date: Date, progress: Float)
    
    public var downloadProgress: Float {
        guard !self.spine.isEmpty else { return 0 }
        let taskCompletedPercentage = self.spine.reduce(0) { (memo: Float, element: SpineElement) -> Float in
            return memo + element.downloadTask.downloadProgress
        }
        ATLog(.debug, "ANS: Overall Download Progress: \(taskCompletedPercentage / Float(self.spine.count))")
        return taskCompletedPercentage / Float(self.spine.count)
    }
  
    /// Since download progress would be 0 if the download has not begun,
    /// we use this computed property to check if the files have been downloaded or not.
    public var downloadCompleted: Bool {
        for spineElement in self.spine {
            if !spineElement.downloadTask.downloadCompleted {
                return false
            }
        }
        return true
    }
  
    public var isDownloading: Bool = false
  
    private let downloadStatusLock = NSRecursiveLock()
    
    private var cursor: Cursor<SpineElement>?

    /// Delegate callbacks will always be invoked on the main thread.
    private var delegates: NSHashTable<AudiobookNetworkServiceDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])
    
    /// Delegate callbacks will always be invoked on the main thread.
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
        self.lastProgressUpdate = (date: Date(), progress: 0)
        self.spine.forEach { (element) in
            element.downloadTask.delegate = self
            self.spineElementByKey[element.downloadTask.key] = element
        }
        self.reachabilityManager = ReachabilityManager.reachability(withHostName: "www.librarysimplified.org")
    }
    
    public func fetch() {
        self.downloadStatusLock.lock()
        defer {
          self.downloadStatusLock.unlock()
        }
        
        guard !isDownloading else {
          return
        }
      
        if self.cursor == nil {
            self.cursor = Cursor(data: self.spine)
        }
        self.cursor?.currentElement.downloadTask.fetch()
        self.isDownloading = true
        self.timeoutTimer = NYPLRepeatingTimer(interval: .seconds(60), handler: { [weak self] in
            self?.performDownloadTaskTimeoutCheck()
        })
    }
  
    public func cancelFetch() {
        self.downloadStatusLock.lock()
        defer {
          self.downloadStatusLock.unlock()
        }
        
        self.spine.forEach { (spineElement) in
            spineElement.downloadTask.cancel()
        }
        self.isDownloading = false
        self.timeoutTimer = nil
    }
  
    private func performDownloadTaskTimeoutCheck() {
        /// If the last progress update has less than 1% difference,
        /// happened more than 10 minutes ago on Wifi,
        /// 8 minutes ago on cellular or 1 minute ago with no internet connection.
        /// We determine it's a timeout and fail the download attempt.
        if downloadProgress - self.lastProgressUpdate.progress <= 0.01 {
            var timeoutLimit = 60.0
            var networkStatus: NetworkStatus = NotReachable
            if let reachabilityManager = reachabilityManager {
              networkStatus = reachabilityManager.currentReachabilityStatus()
              switch networkStatus {
              case ReachableViaWWAN:
                timeoutLimit = 60.0 * 8.0
              case ReachableViaWiFi:
                timeoutLimit = 60.0 * 10.0
              default:
                timeoutLimit = 60.0
              }
            }
            
            if Date().timeIntervalSince(lastProgressUpdate.date) >= timeoutLimit {
                DispatchQueue.main.async { [weak self] () -> Void in
                    self?.cancelFetch()
                    self?.notifyDelegatesOfTimeout(for: self?.cursor?.currentElement,
                                                   networkStatus: networkStatus)
                }
            }
        }
    }
}

extension DefaultAudiobookNetworkService: DownloadTaskDelegate {
    public func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
        self.downloadStatusLock.lock()
        defer {
          self.downloadStatusLock.unlock()
        }
        
        self.cursor = self.cursor?.next()
        self.cursor?.currentElement.downloadTask.fetch()
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesThatPlaybackIsReady(for: spineElement)
            }
        }
        
        if downloadProgress == 1.0 {
            self.timeoutTimer = nil
            self.isDownloading = false
        }
    }

    public func downloadTaskDidDeleteAsset(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesOfDelete(for: spineElement)
            }
        }
    }

    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        self.downloadStatusLock.lock()
        defer {
          self.downloadStatusLock.unlock()
        }
        
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.lastProgressUpdate = (date: Date(), progress: downloadProgress)
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesOfDownloadPercent(for: spineElement)
            }
        }
    }

    public func downloadTaskFailed(_ downloadTask: DownloadTask, withError error: NSError?) {
        self.downloadStatusLock.lock()
        defer {
          self.downloadStatusLock.unlock()
        }
        
        self.timeoutTimer = nil
        self.cursor = nil
        self.isDownloading = false
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.notifyDelegatesThatErrorWasReceived(for: spineElement, error: error)
            }
        }
    }
  
    public func downloadTaskExceededTimeLimit(_ downloadTask: DownloadTask, elapsedTime: Double) {
        guard let spineElement = self.spineElementByKey[downloadTask.key] else {
            return
        }
        self.notifyDelegatesOfDownloadExceededTimeLimit(for: spineElement,
                                                        elapsedTime: elapsedTime,
                                                        networkStatus: reachabilityManager?.currentReachabilityStatus() ?? NotReachable)
    }

    // MARK: - Delegate Helper

    /// - Important: Must be called on the main thread.
    private func notifyDelegatesThatPlaybackIsReady(for spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didCompleteDownloadFor: spineElement)
            delegate.audiobookNetworkService(self, didUpdateOverallDownloadProgress: self.downloadProgress)
        }
    }

    /// - Important: Must be called on the main thread.
    private func notifyDelegatesOfDownloadPercent(for spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didUpdateProgressFor: spineElement)
            delegate.audiobookNetworkService(self, didUpdateOverallDownloadProgress: self.downloadProgress)
        }
    }

    /// - Important: Must be called on the main thread.
    private func notifyDelegatesThatErrorWasReceived(for spineElement: SpineElement, error: NSError?) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didReceive: error, for: spineElement)
        }
    }
    
    /// This is called on background thread.
    /// The class responding to `audiobookNetworkService(_:didTimeoutFor:networkStatus:)`
    /// needs to switch back to main thread if UI updated is needed.
    private func notifyDelegatesOfTimeout(for spineElement: SpineElement?, networkStatus: NetworkStatus) {
        self.delegates.allObjects.forEach { delegate in
            delegate.audiobookNetworkService(self,
                                             didTimeoutFor: spineElement,
                                             networkStatus: networkStatus)
        }
    }
  
    /// No UI update is needed, can be called on background thread.
    private func notifyDelegatesOfDownloadExceededTimeLimit(for spineElement: SpineElement,
                                                            elapsedTime: TimeInterval,
                                                            networkStatus: NetworkStatus)
    {
        self.delegates.allObjects.forEach { delegate in
            delegate.audiobookNetworkService(self,
                                             downloadExceededTimeLimitFor: spineElement,
                                             elapsedTime: elapsedTime,
                                             networkStatus: networkStatus)
        }
    }
    
    /// - Important: Must be called on the main thread.
    private func notifyDelegatesOfDelete(for spineElement: SpineElement) {
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookNetworkService(self, didDeleteFileFor: spineElement)
        }
    }
}
