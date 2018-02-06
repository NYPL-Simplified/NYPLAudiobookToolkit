//
//  FindawayPlaybackNotificationHandler.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/5/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

protocol FindawayPlaybackNotificationHandlerDelegate: class {
    func playbackNotification()
    func audioEngineChapterPlaybackStarted()
    func audioEngineChapterPlaybackPaused()
}

protocol FindawayPlaybackNotificationHandler {
    weak var delegate: FindawayPlaybackNotificationHandlerDelegate? { get set }
}

/// TODO: Make a protocol to interact with this
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
            selector: #selector(DefaultFindawayPlaybackNotificationHandler.audioEngineChapterUpdate(_:)),
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
        print("DEANDEBUG streaming began \(notification.userInfo)")
    }

    @objc func audioEngineChapterUpdate(_ notification: NSNotification) {
        print("DEANDEBUG chapter update \(notification.userInfo)")
    }
    
    @objc func audioEngineChapterPlaybackStarted(_ notification: NSNotification) {
        print("DEANDEBUG chapter playback started \(notification.userInfo)")
        self.delegate?.audioEngineChapterPlaybackStarted()
    }
    
    @objc func audioEngineChapterPlaybackPaused(_ notification: NSNotification) {
        print("DEANDEBUG chapter playback started \(notification.userInfo)")
        self.delegate?.audioEngineChapterPlaybackPaused()
    }
}
