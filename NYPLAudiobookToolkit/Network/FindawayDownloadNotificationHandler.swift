//
//  FindawayDownloadNotificationHandler.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/26/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

@objc protocol FindawayDownloadNotificationHandlerDelegate: class {
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didReceive error: NSError, for downloadRequestID: String)
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didDeleteAudiobookFor chapterDescription: FAEChapterDescription)
}

@objc protocol FindawayDownloadNotificationHandler: class {
    weak var delegate: FindawayDownloadNotificationHandlerDelegate? { get set }
}

class DefaultFindawayDownloadNotificationHandler: FindawayDownloadNotificationHandler {
    weak var delegate: FindawayDownloadNotificationHandlerDelegate?
    public init() {
        // DOWNLOAD LIFECYCLE
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineDidStartDownload(_:)),
            name: NSNotification.Name.FAEChapterDownloadStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineDidSucceed(_:)),
            name: NSNotification.Name.FAEChapterDownloadSuccess,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineDidSucceed(_:)),
            name: NSNotification.Name.FAEDownloadRequestPaused,
            object: nil
        )

        // ERRORS
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineDidReceiveError(_:)),
            name: NSNotification.Name.FAEDownloadRequestFailed,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineDidReceiveError(_:)),
            name: NSNotification.Name.FAEChapterDownloadFailed,
            object: nil
        )

        // DELETE
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineDidDeleteChapter(_:)),
            name: NSNotification.Name.FAEChapterDeleteSuccess,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public func audioEngineDidReceiveError(_ notification: NSNotification) {
        guard let downloadRequestID = notification.userInfo?["DownloadRequestID"] as? String else { return }
        guard let audiobookError = notification.userInfo?["AudioEngineError"] as? NSError else { return }
        self.delegate?.findawayDownloadNotificationHandler(self, didReceive: audiobookError, for: downloadRequestID)
    }

    @objc public func audioEngineDidDeleteChapter(_ notification: NSNotification) {
        print("DEANDEBUG userInfo for delete \(notification.userInfo)")
        guard let chapterDescription = notification.userInfo?["ChapterDescription"] as? FAEChapterDescription else { return }
        self.delegate?.findawayDownloadNotificationHandler(self, didDeleteAudiobookFor: chapterDescription)
    }

    @objc public func audioEngineDidStartDownload(_ notification: NSNotification) {
        guard let chapterDescription = notification.userInfo?["ChapterDescription"] as? FAEChapterDescription else { return }
        self.delegate?.findawayDownloadNotificationHandler(self, didStartDownloadFor: chapterDescription)
    }

    @objc public func audioEngineDidPauseDownload(_ notification: NSNotification) {
        guard let chapterDescription = notification.userInfo?["ChapterDescription"] as? FAEChapterDescription else { return }
        self.delegate?.findawayDownloadNotificationHandler(self, didStartDownloadFor: chapterDescription)
    }

    @objc public func audioEngineDidSucceed(_ notification: NSNotification) {
        print("DEANDEBUG userInfo for download \(notification.userInfo)")
        guard let chapterDescription = notification.userInfo?["ChapterDescription"] as? FAEChapterDescription else { return }
        self.delegate?.findawayDownloadNotificationHandler(self, didSucceedDownloadFor: chapterDescription)
    }
}
