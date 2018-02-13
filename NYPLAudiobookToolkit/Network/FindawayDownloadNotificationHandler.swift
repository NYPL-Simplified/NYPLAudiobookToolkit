//
//  FindawayDownloadNotificationHandler.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/13/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

/// Delegate to be notified when download status changes for specific chapters
@objc protocol FindawayDownloadNotificationHandlerDelegate: class {
    
    /**
     Notifications that a download finished for a chapter
     */
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didDetectDownload chapter: FAEChapterDescription)
}

@objc protocol FindawayDownloadNotificationHandler {
    weak var delegate: FindawayDownloadNotificationHandlerDelegate? { get set }
}

class DefaultFindawayDownloadNotificationHandler: NSObject, FindawayDownloadNotificationHandler {
    weak var delegate: FindawayDownloadNotificationHandlerDelegate?
    public override init() {
        super.init()
        
        // Streaming notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineChapterDownloadUpdate(_:)),
            name: NSNotification.Name.FAEChapterDownloadSuccess,
            object: nil
        )
    }
    
    @objc func audioEngineChapterDownloadUpdate(_ notification: NSNotification) {
        if let chapter = notification.userInfo?["ChapterDescription"] as? FAEChapterDescription {
            self.delegate?.findawayDownloadNotificationHandler(self, didDetectDownload: chapter)
        }
    }
}
