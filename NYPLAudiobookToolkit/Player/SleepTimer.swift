//
//  SleepTimer.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 3/7/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc public enum SleepTimerTriggerAt: Int {
    case never
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case endOfChapter
}

@objc public final class SleepTimer: NSObject {
    private let player: Player
    private let queue = DispatchQueue(label: "com.nyplaudiobooktoolkit.SleepTimer")
    public var isScheduled: Bool {
        var value = false
        self.queue.sync { [weak self] () -> Void in
            if let strongSelf = self {
                value = strongSelf.trigger != .never
            }
        }
        return value
    }

    public var timeToSleep: TimeInterval {
        var tts = TimeInterval(0)
        self.queue.sync {
            tts = self._timeToSleep
        }
        return tts
    }
    private var _timeToSleep: TimeInterval = 0
    private var trigger: SleepTimerTriggerAt = .never

    public func cancel() {
        self.queue.sync {  [weak self] () -> Void in
            self?.trigger = .never
            self?._timeToSleep = 0
        }
    }

    public func startTimerFor(trigger: SleepTimerTriggerAt) {
        self.queue.sync { [weak self] () -> Void in
            self?.update(trigger: trigger)
        }
    }
    
    private func update(trigger: SleepTimerTriggerAt) {
        self.trigger = trigger
        let minutes: (_ timeInterval: TimeInterval) -> TimeInterval = { $0 * 60}
        switch self.trigger {
        case .fifteenMinutes:
            self._timeToSleep = minutes(15)
        case .thirtyMinutes:
            self._timeToSleep = minutes(30)
        case .oneHour:
            self._timeToSleep = minutes(60)
        default:
            self._timeToSleep = 0
        }
        self.scheduleTimerIfNeeded()
    }

    private func scheduleTimerIfNeeded() {
        let oneSecond = DispatchWallTime(timespec: timespec(tv_sec: 1, tv_nsec: 0))
        self.queue.asyncAfter(wallDeadline: oneSecond) { [weak self] () -> Void in
            self?.checkTimerStateAndScheduleNextRun()
        }
    }
    
    private func checkTimerStateAndScheduleNextRun() {
        if self.trigger != .never && self._timeToSleep > 0 {
            self._timeToSleep = self._timeToSleep - 1
            print("DEANDEBUG time is slipping \(self._timeToSleep)")
            if self._timeToSleep <= 0 {
                DispatchQueue.main.async { [weak self] () -> Void in
                    self?.player.pause()
                }
                self.trigger = .never
            } else {
                self.scheduleTimerIfNeeded()
            }
        }
    }

    init(player: Player) {
        self.player = player
        super.init()
        self.player.registerDelegate(self)
    }
    
    deinit {
        self.player.removeDelegate(self)
    }
}

extension SleepTimer: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) { }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        if self.trigger == .endOfChapter {
            DispatchQueue.main.async {
                player.pause()
            }
            self.queue.async {
                self.trigger = .never
                self._timeToSleep = 0
            }
        }
    }
}


