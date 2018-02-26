//
//  FindawayDownloadNotificationHandler.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/26/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc protocol FindawayDownloadNotificationHandlerDelegate: class {
    
    /**
     Notifications specific to errors. The lifeCycleManager does not retain errors, simply listens for them and passes them forward.
     The reason for this is multiple clients can be fetching books at once, but there should be only one AudiobookLifeCycleManager.
     */
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didRecieve error: AudiobookError)
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
        guard let audiobookID = notification.userInfo?["audiobookID"] as? String else { return }
        guard let downloadRequestID = notification.userInfo?["DownloadRequestID"] as? String else { return }
        guard let audiobookError = notification.userInfo?["AudioEngineError"] as? NSError else { return }
        self.delegate?.findawayDownloadNotificationHandler(self, didRecieve: DefaultAudiobookError(error: audiobookError, audiobookID: audiobookID))
    }
}
