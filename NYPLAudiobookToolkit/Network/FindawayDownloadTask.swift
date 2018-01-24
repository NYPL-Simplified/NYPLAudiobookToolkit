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
    
    private var downloadStatus: FAEDownloadStatus {
        var status = FAEDownloadStatus.notDownloaded
        if let audiobookID = self.spine.first?.audiobookID {
            status = FAEAudioEngine.shared()?.downloadEngine?.status(forAudiobookID: audiobookID) ?? .notDownloaded
        }
        return status
    }

    private var timer: Timer?
    public init(spine: [FindawayFragment]) {
        self.spine = spine
    }
    
    public func fetch() {
        guard let fragment = self.spine.first else { return }

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
            FAEAudioEngine.shared()?.downloadEngine?.delete(forAudiobookID: downloadRequest.audiobookID)
            FAEAudioEngine.shared()?.downloadEngine?.startDownload(with: downloadRequest)
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] (timer) in
                self?.notifyDelegates()
            })
        }
    }
    
    private func notifyDelegates() {
        self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
        if self.downloadStatus == .downloaded {
            self.timer?.invalidate()
            self.delegate?.downloadTaskDidComplete(self)
        }
    }
    
}
