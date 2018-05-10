//
//  AudiobookLifecycleManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AVFoundation

@objc public protocol AudiobookLifecycleListener: class {
    func didFinishLaunching()
    func didEnterBackground()
    func willTerminate()
    func handleBackgroundURLSession(for identifier: String, completionHandler: @escaping () -> Void) -> Bool
    init()
}

/// Hooks into life cycle events for AppDelegate.swift. Listens to notifcations from
/// AudioEngine to ensure other objects know when it is safe to perform operations on
/// their SDK.
public class AudiobookLifecycleManager: NSObject {
    /**
     The shared instance of the lifecycle manager intended for usage throughout the framework.
     */
    public func didFinishLaunching () {
        self.listeners.forEach { (listener) in
            listener.didFinishLaunching()
        }
    }
    
    public func didEnterBackground () {
        self.listeners.forEach { (listener) in
            listener.didEnterBackground()
        }
    }
    
    public func willTerminate () {
        self.listeners.forEach { (listener) in
            listener.willTerminate()
        }
    }
    
    public func handleEventsForBackgroundURLSession(for identifier: String, completionHandler: @escaping () -> Void) {
        for listener in self.listeners {
            let didHandle = listener.handleBackgroundURLSession(for: identifier, completionHandler: completionHandler)
            if didHandle {
                break
            }
        }
    }

    private var listeners = [AudiobookLifecycleListener]()
    public override init() {
        super.init()
        let FindawayListenerClass = NSClassFromString("NYPLAEToolkit.FindawayAudiobookLifecycleListener") as? AudiobookLifecycleListener.Type
        let findawayListener = FindawayListenerClass?.init()
        if let listener = findawayListener {
            self.listeners.append(listener)
        }
    }
}

