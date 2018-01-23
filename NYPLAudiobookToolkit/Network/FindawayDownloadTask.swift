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
            FAEAudioEngine.shared()?.downloadEngine?.startDownload(with: downloadRequest)
            let completion = { [weak self] in
                if let strongSelf = self {
                    self?.delegate?.downloadTaskDidComplete(strongSelf)
                }
            }
            FAEAudioEngine.shared()?.downloadEngine?.addCompletionHandler(completion, forSession: fragment.sessionKey)
        }
    }
    
    
}
