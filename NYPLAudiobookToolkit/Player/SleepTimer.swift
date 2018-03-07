//
//  SleepTimer.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 3/7/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc public enum SleepTimerTriggerAt: UInt {
    case never
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case endOfChapter
}

@objc public final class SleepTimer: NSObject {
    public var isScheduled: Bool {
        return self.trigger != .never
    }

    public func startTimerFor(trigger: SleepTimerTriggerAt) {
        self.trigger = trigger
        let oneMinute: TimeInterval = 60
        switch self.trigger {
        case .fifteenMinutes:
            self.createTimerWith(timeInterval: oneMinute * 15)
        case .thirtyMinutes:
            self.createTimerWith(timeInterval: oneMinute * 30)
        case .oneHour:
            self.createTimerWith(timeInterval: oneMinute * 60)
        default:
            break
        }
    }

    public func cancel() {
        self.trigger = .never
    }

    private func createTimerWith(timeInterval: TimeInterval) {
        self.timer = Timer.scheduledTimer(
            timeInterval: timeInterval,
            target: self,
            selector: #selector(SleepTimer.timerToStopPlayer(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    @objc func timerToStopPlayer(_ timer: Timer) {
        if self.isScheduled {
            self.player.pause()
        }
        self.trigger = .never
    }
    

    private var trigger: SleepTimerTriggerAt = .never {
        didSet {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    private var timer: Timer?
    private let player: Player
    init(player: Player) {
        self.player = player
        super.init()
        self.player.registerDelegate(self)
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
}

extension SleepTimer: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) { }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        if self.trigger == .endOfChapter {
            player.pause()
            self.trigger = .never
        }
    }
}


