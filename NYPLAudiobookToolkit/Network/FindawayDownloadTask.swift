//
//  FindawayLibrarian.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

class FindawayDownloadTask: DownloadTask {
    var error: AudiobookError?
    weak var delegate: DownloadTaskDelegate?
    let spine: [FindawayFragment]
    var downloadProgress: Float {
        var progress: Float = 0
        if let fragment = self.spine.first {
            progress = findawayProgressToNYPLToolkit(
                FAEAudioEngine.shared()?.downloadEngine?.percentage(forAudiobookID: fragment.audiobookID)
            )
        }
        return progress
    }
    
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

    public init(spine: [FindawayFragment], audiobookLifeCycleManager: AudiobookLifecycleManagment, downloadRequest: FAEDownloadRequest?) {
        self.spine = spine
        self.databaseHasBeenVerified = audiobookLifeCycleManager.audioEngineDatabaseHasBeenVerified
        if !self.databaseHasBeenVerified {
            audiobookLifeCycleManager.registerDelegate(self)
        }
        self.downloadRequest = downloadRequest
    }

    convenience init(spine: [FindawayFragment]) {
        var request: FAEDownloadRequest?
        if let fragment =  spine.first {
            request = FAEAudioEngine.shared()?.downloadEngine?.currentDownloadRequests().first(where: { (existingRequest) -> Bool in
                existingRequest.audiobookID == fragment.audiobookID
            })
            if request == nil {
                request = FAEDownloadRequest(
                    audiobookID: fragment.audiobookID,
                    partNumber: fragment.partNumber,
                    chapterNumber: fragment.chapterNumber,
                    downloadType: .fullWrap,
                    sessionKey: fragment.sessionKey,
                    licenseID: fragment.licenseID,
                    restrictToWiFi: false
                )
            }
        }
        self.init(spine: spine, audiobookLifeCycleManager: AudiobookLifecycleManager.shared, downloadRequest: request)
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }

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
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] (timer) in
                self?.notifyDelegate()
            })
        }
    }
    
    private func notifyDelegate() {
        self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
        if self.downloadStatus == .downloaded {
            self.timer?.invalidate()
            self.delegate?.downloadTaskReadyForPlayback(self)
        }
    }
}

extension FindawayDownloadTask: AudiobookLifecycleManagmentDelegate {
    func audiobookLifecycleManager(_ audiobookLifecycleManager: AudiobookLifecycleManagment, didRecieve error: AudiobookError) {
        guard let audiobookID = self.spine.first?.audiobookID else { return }
        if error.audiobookID == audiobookID {
            self.error = error
            self.delegate?.downloadTaskDidError(self)
        }
    }
    
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifecycleManagment) {
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
