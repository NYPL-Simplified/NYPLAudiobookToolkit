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
        guard self.databaseHasBeenVerified else {
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
        return self.downloadRequest.requestIdentifier
    }

    private var timer: Timer?
    private var retryAfterVerification = false
    private var databaseHasBeenVerified: Bool
    private var downloadRequest: FAEDownloadRequest
    private var downloadStatus: FAEDownloadStatus {
        var status = FAEDownloadStatus.notDownloaded
        guard self.databaseHasBeenVerified else {
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
        guard self.databaseHasBeenVerified else {
            return false
        }
        
        return FAEAudioEngine.shared()?.downloadEngine?.currentDownloadRequests().isEmpty ?? false
    }

    private var notifiedDownloadProgress: Float = nan("Download Progress has not started yet")
    private let notificationHandler: FindawayDownloadNotificationHandler
    public init(audiobookLifeCycleManager: AudiobookLifeCycleManager, findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, downloadRequest: FAEDownloadRequest) {
        self.downloadRequest = downloadRequest
        self.notificationHandler = findawayDownloadNotificationHandler
        self.databaseHasBeenVerified = audiobookLifeCycleManager.audioEngineDatabaseHasBeenVerified

        self.notificationHandler.delegate = self
        if !self.databaseHasBeenVerified {
            audiobookLifeCycleManager.registerDelegate(self)
        }
    }

    convenience init(spineElement: FindawaySpineElement) {
        var request = FAEAudioEngine.shared()?.downloadEngine?.currentDownloadRequests().first(where: { (existingRequest) -> Bool in
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
            downloadRequest: request!
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
        guard self.databaseHasBeenVerified else {
            self.retryAfterVerification = true
            return
        }

        guard self.downloadStatus != .downloaded else {
            self.delegate?.downloadTaskReadyForPlayback(self)
            return
        }
    
        FAEAudioEngine.shared()?.downloadEngine?.startDownload(with: self.downloadRequest)
        self.timer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(FindawayDownloadTask.pollForDownloadPercentage(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc func pollForDownloadPercentage(_ timer: Timer) {
        self.notifyDelegate()
    }

    private func notifyDelegate() {
        if self.notifiedDownloadProgress != self.downloadProgress {
            self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
            self.notifiedDownloadProgress = self.downloadProgress
        }
        if self.downloadStatus == .downloaded {
            self.timer?.invalidate()
            self.delegate?.downloadTaskReadyForPlayback(self)
        }
    }

    /// This implementation of delete must be sure to set a new download request
    /// once the chapter has deleted. If a user attempts to download a book with a
    /// request thats already been deleted from the filesystem, then the engine will
    /// throw an error.
    public func delete() {
        FAEAudioEngine.shared()?.downloadEngine?.delete(
            forAudiobookID: self.downloadRequest.audiobookID,
            partNumber: self.downloadRequest.partNumber,
            chapterNumber: self.downloadRequest.chapterNumber
        )
        self.delegate?.downloadTaskDidDeleteAsset(self)
        self.downloadRequest = FAEDownloadRequest(
            audiobookID: self.downloadRequest.audiobookID,
            partNumber: self.downloadRequest.partNumber,
            chapterNumber: self.downloadRequest.chapterNumber,
            downloadType: self.downloadRequest.downloadType,
            sessionKey: self.downloadRequest.sessionKey,
            licenseID: self.downloadRequest.licenseID,
            restrictToWiFi: self.downloadRequest.restrictToWiFi
        )!
    }
}

extension FindawayDownloadTask: FindawayDownloadNotificationHandlerDelegate {
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didReceive error: NSError, for downloadRequestID: String) {
        if self.downloadRequest.requestIdentifier == downloadRequestID {
            self.timer?.invalidate()
            self.delegate?.downloadTask(self, didReceive: error)
        }
    }
}

extension FindawayDownloadTask: AudiobookLifecycleManagerDelegate {
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifeCycleManager) {
        self.databaseHasBeenVerified = audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified
        guard self.databaseHasBeenVerified else { return }
        guard self.retryAfterVerification else { return }
        self.fetch()
    }
}

private func findawayProgressToNYPLToolkit(_ progress: Float?) -> Float {
    var toolkitProgress: Float = 0
    if let progress = progress {
        toolkitProgress = progress / 100
    }
    return toolkitProgress
}
