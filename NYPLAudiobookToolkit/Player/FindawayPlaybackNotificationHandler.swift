//
//  FindawayPlaybackNotificationHandler.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/5/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

protocol FindawayPlaybackNotificationHandlerDelegate: class {
    func audioEnginePlaybackStarted(_ notificationHandler: FindawayPlaybackNotificationHandler, for chapter: FAEChapterDescription)
    func audioEnginePlaybackPaused(_ notificationHandler: FindawayPlaybackNotificationHandler, for chapter: FAEChapterDescription)
    func audioEnginePlaybackStreaming(_ notificationHandler: FindawayPlaybackNotificationHandler, for chapter: FAEChapterDescription)
    func audioEnginePlaybackLoaded(_ notificationHandler: FindawayPlaybackNotificationHandler, for chapter: FAEChapterDescription)
}

protocol FindawayPlaybackNotificationHandler {
    weak var delegate: FindawayPlaybackNotificationHandlerDelegate? { get set }
}

/// This class wraps notifications from AudioEngine and notifies its delegate. It has no behavior on its own and should only be used to get updates on playback/streaming status from AudioEngine.
class DefaultFindawayPlaybackNotificationHandler: NSObject, FindawayPlaybackNotificationHandler {
    weak var delegate: FindawayPlaybackNotificationHandlerDelegate?
    public override init() {
        super.init()
        
        // Streaming notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineStreamingBegan(_:)),
            name: NSNotification.Name.FAEPlaybackStreamingRequestStarted,
            object: nil
        )
        
        // Chapter Playback
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineChapterLoaded(_:)),
            name: NSNotification.Name.FAEPlaybackChapterLoaded,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineChapterPlaybackStarted(_:)),
            name: NSNotification.Name.FAEPlaybackChapterStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineChapterUpdate(_:)),
            name: NSNotification.Name.FAEPlaybackChapterFailed,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineChapterUpdate(_:)),
            name: NSNotification.Name.FAEPlaybackChapterComplete,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineChapterPlaybackPaused(_:)),
            name: NSNotification.Name.FAEPlaybackChapterPaused,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineChapterUpdate(_:)),
            name: NSNotification.Name.FAEPlaybackChapterPausedFailed,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func audioEngineStreamingBegan(_ notification: NSNotification) {
        if let chapter = notification.userInfo?[FAEChapterDescriptionUserInfoKey] as? FAEChapterDescription {
            self.delegate?.audioEnginePlaybackStreaming(self, for: chapter)
        }
    }

    @objc func audioEngineChapterLoaded(_ notification: NSNotification) {
        if let chapter = notification.userInfo?[FAEChapterDescriptionUserInfoKey] as? FAEChapterDescription {
            self.delegate?.audioEnginePlaybackLoaded(self, for: chapter)
        }
    }

    @objc func audioEngineChapterUpdate(_ notification: NSNotification) {
    }
    
    @objc func audioEngineChapterPlaybackStarted(_ notification: NSNotification) {
        if let chapter = notification.userInfo?[FAEChapterDescriptionUserInfoKey] as? FAEChapterDescription {
            self.delegate?.audioEnginePlaybackStarted(self, for: chapter)
        }
    }
    
    @objc func audioEngineChapterPlaybackPaused(_ notification: NSNotification) {
        if let chapter = notification.userInfo?[FAEChapterDescriptionUserInfoKey] as? FAEChapterDescription {
            self.delegate?.audioEnginePlaybackPaused(self, for: chapter)
        }
    }
}
