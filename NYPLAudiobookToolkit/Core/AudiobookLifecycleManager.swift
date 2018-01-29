//
//  AudiobookLifecycleManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

@objc protocol AudiobookLifecycleManagmentDelegate: class {
    func audiobookLifecycleManagerDidUpdate(_ audiobookLifecycleManager: AudiobookLifecycleManagment)
    func audiobookLifecycleManager(_ audiobookLifecycleManager: AudiobookLifecycleManagment, didRecieve error: AudiobookError)
}

@objc protocol AudiobookLifecycleManagment: class {
    var audioEngineDatabaseHasBeenVerified: Bool { get }
    func didFinishLaunching()
    func didEnterBackground()
    func willTerminate()
    func registerDelegate(_ delegate: AudiobookLifecycleManagmentDelegate)
    func removeDelegate(_ delegate: AudiobookLifecycleManagmentDelegate)
}

public class AudiobookLifecycleManager: NSObject, AudiobookLifecycleManagment {
    public static let shared = AudiobookLifecycleManager()
    private var delegates: NSHashTable<AudiobookLifecycleManagmentDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])
    public var audioEngineDatabaseHasBeenVerified: Bool {
        return _audioEngineDatabaseHasBeenVerified
    }
    private var _audioEngineDatabaseHasBeenVerified = false
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AudiobookLifecycleManager.audioEngineDatabaseVerificationStatusHasBeenUpdated(_:)),
            name: NSNotification.Name.FAEDatabaseVerificationComplete,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AudiobookLifecycleManager.audioEngineDidRecieveError(_:)),
            name: NSNotification.Name.FAEDownloadRequestFailed,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func registerDelegate(_ delegate: AudiobookLifecycleManagmentDelegate) {
        self.delegates.add(delegate)
    }
    
    func removeDelegate(_ delegate: AudiobookLifecycleManagmentDelegate) {
        self.delegates.remove(delegate)
    }

    @objc public func audioEngineDatabaseVerificationStatusHasBeenUpdated(_ notification: NSNotification) {
        self._audioEngineDatabaseHasBeenVerified = true
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookLifecycleManagerDidUpdate(self)
        }
    }
    
    @objc public func audioEngineDidRecieveError(_ notification: NSNotification) {
        guard let audiobookID = notification.userInfo?["audiobookID"] as? String else { return }
        guard let audiobookError = notification.userInfo?["audioEngineError"] as? NSError else { return }
        self.delegates.allObjects.forEach { (delegate) in
            delegate.audiobookLifecycleManager(self,
                didRecieve: DefaultAudiobookError(error: audiobookError, audiobookID: audiobookID)
            )
        }
    }
}

extension AudiobookLifecycleManager {
    public func didFinishLaunching () {
        FAEAudioEngine.shared()?.didFinishLaunching()
        FAELogEngine.setLogLevel(.verbose)
    }
    
    public func didEnterBackground () {
        FAEAudioEngine.shared()?.didEnterBackground()
    }
    
    public func willTerminate () {
        FAEAudioEngine.shared()?.willTerminate()
    }
    
    public func handleEventsForBackgroundURLSession(for identifier: String, completionHandler: @escaping () -> Void) {
        if identifier.contains("FWAE") {
            FAEAudioEngine.shared()?.didFinishLaunching()
            FAEAudioEngine.shared()?.downloadEngine?.addCompletionHandler(completionHandler, forSession: identifier)
        }
    }
}
