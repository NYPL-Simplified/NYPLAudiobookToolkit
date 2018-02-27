//
//  FindawayDownloadNotificationHandler.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/26/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc protocol FindawayDownloadNotificationHandlerDelegate: class {
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didReceive error: NSError, for downloadRequestID: String)
}

@objc protocol FindawayDownloadNotificationHandler: class {
    weak var delegate: FindawayDownloadNotificationHandlerDelegate? { get set }
}

class DefaultFindawayDownloadNotificationHandler: FindawayDownloadNotificationHandler {
    weak var delegate: FindawayDownloadNotificationHandlerDelegate?
    public init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayDownloadNotificationHandler.audioEngineDidReceiveError(_:)),
            name: NSNotification.Name.FAEDownloadRequestFailed,
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
}
