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
class FindawayDownloadTask: DownloadTask {
    var error: AudiobookError?
    weak var delegate: DownloadTaskDelegate?
    let spine: [FindawaySpineElement]
    var downloadProgress: Float {
        return findawayProgressToNYPLToolkit(
            FAEAudioEngine.shared()?.downloadEngine?.percentage(forAudiobookID: self.firstSpineElement.audiobookID)
        )
    }
    
    private let firstSpineElement: FindawaySpineElement
    private var timer: Timer?
    private var retryAfterVerification = false
    private var databaseHasBeenVerified: Bool
    private var downloadRequest: FAEDownloadRequest?
    private var downloadStatus: FAEDownloadStatus {
        var status = FAEDownloadStatus.notDownloaded
        if let audiobookID = self.downloadRequest?.audiobookID {
            status = FAEAudioEngine.shared()?.downloadEngine?.status(forAudiobookID: audiobookID) ?? .notDownloaded
        }
        return status
    }

    public init(spine: [FindawaySpineElement], spineElement: FindawaySpineElement, audiobookLifeCycleManager: AudiobookLifeCycleManager, downloadRequest: FAEDownloadRequest?) {
        self.spine = spine
        self.firstSpineElement = spineElement
        self.databaseHasBeenVerified = audiobookLifeCycleManager.audioEngineDatabaseHasBeenVerified
        if !self.databaseHasBeenVerified {
            audiobookLifeCycleManager.registerDelegate(self)
        }
        self.downloadRequest = downloadRequest
    }

    convenience init(spine: [FindawaySpineElement], spineElement: FindawaySpineElement) {
        var request = FAEAudioEngine.shared()?.downloadEngine?.currentDownloadRequests().first(where: { (existingRequest) -> Bool in
            existingRequest.audiobookID == spineElement.audiobookID
        })
        if request == nil {
            request = FAEDownloadRequest(
                audiobookID: spineElement.audiobookID,
                partNumber: spineElement.partNumber,
                chapterNumber: spineElement.chapterNumber,
                downloadType: .fullWrap,
                sessionKey: spineElement.sessionKey,
                licenseID: spineElement.licenseID,
                restrictToWiFi: false
            )
        }
        self.init(spine: spine, spineElement: spineElement, audiobookLifeCycleManager: DefaultAudiobookLifecycleManager.shared, downloadRequest: request)
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

        if let downloadRequest = self.downloadRequest {
            FAEAudioEngine.shared()?.downloadEngine?.startDownload(with: downloadRequest)
            self.timer = Timer.scheduledTimer(
                timeInterval: 0.5,
                target: self,
                selector: #selector(FindawayDownloadTask.pollForDownloadPercentage(_:)),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    @objc func pollForDownloadPercentage(_ timer: Timer) {
        self.notifyDelegate()
    }

    private func notifyDelegate() {
        self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
        if self.downloadStatus == .downloaded {
            self.timer?.invalidate()
            self.delegate?.downloadTaskReadyForPlayback(self)
        }
    }
}

extension FindawayDownloadTask: AudiobookLifecycleManagerDelegate {
    func audiobookLifecycleManager(_ audiobookLifecycleManager: AudiobookLifeCycleManager, didRecieve error: AudiobookError) {
        guard let audiobookID = self.spine.first?.audiobookID else { return }
        if error.audiobookID == audiobookID {
            self.error = error
            self.delegate?.downloadTaskDidError(self)
        }
    }
    
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
