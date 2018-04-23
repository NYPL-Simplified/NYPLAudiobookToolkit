//
//  AppDelegate.swift
//  NYPLAudiobookToolkitDemoApp
//
//  Created by Dean Silfen on 1/16/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit
import AVKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var audiobookController = AudiobookController()
    let audiobookLifecycleManager = DefaultAudiobookLifecycleManager.shared
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        self.audiobookLifecycleManager.didFinishLaunching()
        let rootVC = self.window?.rootViewController?.childViewControllers.first as? ViewController
        rootVC?.audiobokController = self.audiobookController

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AppDelegate.handleAudioInterruption(_:)),
                                               name: .AVAudioSessionInterruption,
                                               object: AVAudioSession.sharedInstance()
        )
        return true
    }

    @objc func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSessionInterruptionType(rawValue: typeValue) else {
                return
        }
        switch type {
        case .began:
            // Audio has been interrupted, save our state and wait for how to proceed
            self.audiobookController.savePlayhead()
        case .ended:
            // Interruption has ended, lets check if playback should resume
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSessionInterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self.audiobookController.manager?.audiobook.player.play()
                }
            }
        }

    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        self.audiobookController.savePlayhead()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.audiobookLifecycleManager.didEnterBackground()
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        self.audiobookController.savePlayhead()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.audiobookLifecycleManager.willTerminate()
        self.audiobookController.savePlayhead()
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        self.audiobookLifecycleManager.handleEventsForBackgroundURLSession(for: identifier, completionHandler: completionHandler)
    }

}

