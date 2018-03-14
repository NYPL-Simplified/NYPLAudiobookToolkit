//
//  FindawayLibrarian.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine


/// Handle network interactions with the AudioEngine SDK.
final class FindawayDownloadTask: DownloadTask {
    weak var delegate: DownloadTaskDelegate?
    var downloadProgress: Float {
        guard self.readyToDownload else {
            return 0
        }

        return findawayProgressToNYPLToolkit(
            FAEAudioEngine.shared()?.downloadEngine?.percentage(
                forAudiobookID: self.downloadRequest.audiobookID,
                partNumber: self.downloadRequest.partNumber,
                chapterNumber: self.downloadRequest.chapterNumber
            )
        )
    }

    var key: String {
        return "FAE.audioEngine/\(self.downloadRequest.audiobookID)/\(self.downloadRequest.partNumber)/\(self.downloadRequest.chapterNumber)"
    }

    private var timer: Timer?
    private var retryAfterVerification = false
    private var readyToDownload: Bool {
        didSet {
            guard self.readyToDownload else { return }
            guard self.retryAfterVerification else { return }
            self.fetch()
        }
    }
    private var downloadRequest: FAEDownloadRequest
    private var downloadStatus: FAEDownloadStatus {
        var status = FAEDownloadStatus.notDownloaded
        guard self.readyToDownload else {
            return status
        }
        
        let statusFromFindaway = FAEAudioEngine.shared()?.downloadEngine?.status(
            forAudiobookID: self.downloadRequest.audiobookID,
            partNumber: self.downloadRequest.partNumber,
            chapterNumber: self.downloadRequest.chapterNumber
        )
        if let storedStatus = statusFromFindaway {
            status = storedStatus
        }
        return status
    }
    
    private var downloadEngineIsFree: Bool {
        guard self.readyToDownload else {
            return false
        }
        
        return FAEAudioEngine.shared()?.downloadEngine?.currentDownloadRequests().isEmpty ?? false
    }

    private var notifiedDownloadProgress: Float = nan("Download Progress has not started yet")
    private let notificationHandler: FindawayDownloadNotificationHandler
    public init(audiobookLifeCycleManager: AudiobookLifeCycleManager, findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, downloadRequest: FAEDownloadRequest) {
        self.downloadRequest = downloadRequest
        self.notificationHandler = findawayDownloadNotificationHandler
        self.readyToDownload = audiobookLifeCycleManager.audioEngineDatabaseHasBeenVerified

        self.notificationHandler.delegate = self
        if !self.readyToDownload {
            audiobookLifeCycleManager.registerDelegate(self)
        }
    }

    convenience init(spineElement: FindawaySpineElement) {
      var request: FAEDownloadRequest! = FAEAudioEngine.shared()?.downloadEngine?.currentDownloadRequests().first(where: { (existingRequest) -> Bool in
            return existingRequest.audiobookID == spineElement.audiobookID
                && existingRequest.chapterNumber == spineElement.chapterNumber
                && existingRequest.chapterNumber == spineElement.partNumber
        })
        
        if request == nil {
            request = FAEDownloadRequest(
                audiobookID: spineElement.audiobookID,
                partNumber: spineElement.partNumber,
                chapterNumber: spineElement.chapterNumber,
                downloadType: .singleChapter,
                sessionKey: spineElement.sessionKey,
                licenseID: spineElement.licenseID,
                restrictToWiFi: false
            )
        }
        self.init(
            audiobookLifeCycleManager: DefaultAudiobookLifecycleManager.shared,
            findawayDownloadNotificationHandler: DefaultFindawayDownloadNotificationHandler(),
            downloadRequest: request
        )
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }

    /**
     This implementation of fetch() will wait until FAEAudioEngine has verified it's database
     before attempting a download. If this object never sees a verified database from updated AudiobookLifeCycleManager
     events, then it will never even hit the network.
     */
    public func fetch() {
        guard self.readyToDownload else {
            self.retryAfterVerification = true
            return
        }
        
        let status = self.downloadStatus
        if status == .notDownloaded {
            self.requestDownload()
        } else if status == .downloaded {
            self.delegate?.downloadTaskReadyForPlayback(self)
        }
    }

    private func requestDownload() {
        FAEAudioEngine.shared()?.downloadEngine?.startDownload(with: self.downloadRequest)
        self.retryAfterVerification = false
    }

    @objc func pollForDownloadPercentage(_ timer: Timer) {
        self.notifyDelegate()
    }

    private func notifyDelegate() {
        if self.notifiedDownloadProgress != self.downloadProgress {
            self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
            self.notifiedDownloadProgress = self.downloadProgress
        }
    }

    /// If we try to download the book again before the deletion has
    /// finished, AudioEngine will throw an error and fail the download.
    ///
    /// After the deletion has finished, we must aquire a new DownloadRequest
    /// in order to perform another download.
    ///
    /// To compensate for this, if `fetch` is called directly after `delete`,
    /// this object ought to wait until the new DownloadRequest is created
    /// and then attempt the `fetch` again.
    public func delete() {
        FAEAudioEngine.shared()?.downloadEngine?.delete(
            forAudiobookID: self.downloadRequest.audiobookID,
            partNumber: self.downloadRequest.partNumber,
            chapterNumber: self.downloadRequest.chapterNumber
        )
        self.readyToDownload = false
    }
}

extension FindawayDownloadTask: FindawayDownloadNotificationHandlerDelegate {
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didPauseDownloadFor chapterDescription: FAEChapterDescription) {
        guard self.isTaskFor(chapterDescription) else { return }
        self.timer?.invalidate()
    }

    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didSucceedDownloadFor chapterDescription: FAEChapterDescription) {
        guard self.isTaskFor(chapterDescription) else { return }
        self.timer?.invalidate()
        self.delegate?.downloadTaskReadyForPlayback(self)
    }
    
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didStartDownloadFor chapterDescription: FAEChapterDescription) {
        guard self.isTaskFor(chapterDescription) else { return }
        guard self.timer != nil else { return }
        self.timer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(FindawayDownloadTask.pollForDownloadPercentage(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didReceive error: NSError, for downloadRequestID: String) {
        if self.downloadRequest.requestIdentifier == downloadRequestID {
            self.timer?.invalidate()
            self.delegate?.downloadTask(self, didReceive: error)
        }
    }

    /// If a user attempts to download a book with a request thats already
    /// been deleted from the filesystem, then AudioEngine will throw an error.
    ///
    /// As a result of this, once we have confirmed that a chapter has been removed,
    /// we instantiate a new FAEDownloadRequest for our asset.
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didDeleteAudiobookFor chapterDescription: FAEChapterDescription) {
        if self.isTaskFor(chapterDescription) {
            self.delegate?.downloadTaskDidDeleteAsset(self)
            self.downloadRequest = FAEDownloadRequest(
                audiobookID: self.downloadRequest.audiobookID,
                partNumber: self.downloadRequest.partNumber,
                chapterNumber: self.downloadRequest.chapterNumber,
                downloadType: self.downloadRequest.downloadType,
                sessionKey: self.downloadRequest.sessionKey,
                licenseID: self.downloadRequest.licenseID,
                restrictToWiFi: self.downloadRequest.restrictToWiFi
            )
            self.readyToDownload = true
        }
    }
    
    func isTaskFor(_ chapter: FAEChapterDescription) -> Bool {
        return self.downloadRequest.audiobookID == chapter.audiobookID &&
            self.downloadRequest.chapterNumber == chapter.chapterNumber &&
            self.downloadRequest.partNumber == chapter.partNumber
    }
}

extension FindawayDownloadTask: AudiobookLifecycleManagerDelegate {
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifeCycleManager) {
        self.readyToDownload = audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified
    }
}

private func findawayProgressToNYPLToolkit(_ progress: Float?) -> Float {
    var toolkitProgress: Float = 0
    if let progress = progress {
        toolkitProgress = progress / 100
    }
    return toolkitProgress
}
