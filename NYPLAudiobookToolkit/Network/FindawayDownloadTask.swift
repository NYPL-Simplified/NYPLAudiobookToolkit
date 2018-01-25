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
    var downloadProgress: Int {
        var progress = 0
        if let fragment = self.spine.first {
            progress = Int(FAEAudioEngine.shared()?.downloadEngine?.percentage(forAudiobookID: fragment.audiobookID) ?? 0)
        }
        return progress
    }
    
    var delegate: DownloadTaskDelegate?
    let spine: [FindawayFragment]

    private var databaseHasBeenVerified: Bool
    private var retryAfterVerification = false

    public init(spine: [FindawayFragment], audiobookLifeCycleManager: AudiobookLifecycleManagment) {
        self.spine = spine
        self.databaseHasBeenVerified = audiobookLifeCycleManager.audioEngineDatabaseHasBeenVerified
        if !self.databaseHasBeenVerified {
            audiobookLifeCycleManager.registerDelegate(self)
        }
    }

    convenience init(spine: [FindawayFragment]) {
        self.init(spine: spine, audiobookLifeCycleManager: AudiobookLifecycleManager.shared)
    }
    
    private var downloadStatus: FAEDownloadStatus {
        var status = FAEDownloadStatus.notDownloaded
        if let audiobookID = self.firstFragment?.audiobookID {
            status = FAEAudioEngine.shared()?.downloadEngine?.status(forAudiobookID: audiobookID) ?? .notDownloaded
        }
        return status
    }

    private var firstFragment: FindawayFragment? {
        return self.spine.first
    }
    
    private var timer: Timer?
    
    public func fetch() {
        guard self.databaseHasBeenVerified else {
            self.retryAfterVerification = true
            return
        }

        guard let fragment = self.firstFragment else {
            return
        }

        guard self.downloadStatus != .downloaded else {
            self.delegate?.downloadTaskReadyForPlayback(self)
            return
        }

        let request = FAEDownloadRequest(
            audiobookID: fragment.audiobookID,
            partNumber: fragment.partNumber,
            chapterNumber: fragment.chapterNumber,
            downloadType: .fullWrap,
            sessionKey: fragment.sessionKey,
            licenseID: fragment.licenseID,
            restrictToWiFi: false
        )

        if let downloadRequest = request {
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
            self.delegate?.downloadTaskDidComplete(self)
        }
    }
}

extension FindawayDownloadTask: AudiobookLifecycleManagmentDelegate {
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifecycleManagment) {
        self.databaseHasBeenVerified = audiobookLifecycleManager.audioEngineDatabaseHasBeenVerified
        if self.databaseHasBeenVerified {
            audiobookLifecycleManager.removeDelegate(self)
            if self.retryAfterVerification {
                self.fetch()
            }
        }
    }
}
