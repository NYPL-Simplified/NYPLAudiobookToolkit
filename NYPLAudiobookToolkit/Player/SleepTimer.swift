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

/// Class used to schedule timers to automatically pause
/// the current playing audiobook. This class must be retained
/// after the timer has been started in order to properly
/// stop the current playing book.
///
/// All methods should block until they can safely access their
/// properties.
@objc public final class SleepTimer: NSObject {
    private let player: Player
    private let queue = DispatchQueue(label: "com.nyplaudiobooktoolkit.SleepTimer")
    
    /// Flag to find out if the timer is currently scheduled.
    public var isScheduled: Bool {
        var value = false
        self.queue.sync {
            value = self.trigger != .never
        }
        return value
    }

    /// Time remaining until the book will be paused.
    public var timeRemaining: TimeInterval {
        var timeRemaining = TimeInterval(0)
        self.queue.sync {
            switch self.trigger {
            case .never:
                break
            case .endOfChapter:
                let playHead = self.player.currentChapterLocation?.playheadOffset ?? 0
                let duration = self.player.currentChapterLocation?.duration ?? 0
                timeRemaining = duration - playHead
            case .fifteenMinutes, .thirtyMinutes, .oneHour:
                if let tts = self.timeToSleep {
                    timeRemaining = abs(Date().timeIntervalSince(tts))
                }
            }
        }
        return timeRemaining
    }

    /// The time for us to pause the player, aka the bedtime.
    private var timeToSleep: Date?
    
    /// The type of trigger, determines if the timer is active
    /// and if the pause will come from a specific time,
    /// or the conclusion of a chapter.
    private var trigger: SleepTimerTriggerAt = .never
    
    /// Cancel the current sleep timer. May be called
    /// when timer is not scheduled.
    public func cancel() {
        self.queue.sync {
            self.update(trigger: .never)
        }
    }

    /// Start a timer for a specific amount of time.
    public func setTimerTo(trigger: SleepTimerTriggerAt) {
        self.queue.sync {
            self.update(trigger: trigger)
        }
    }

    private func update(trigger: SleepTimerTriggerAt) {
        func timeToSleepIn(_ minutesFromNow: TimeInterval?) {
            var newTime: Date? = nil
            if let minutesFromNow = minutesFromNow {
                newTime = Date().addingTimeInterval(minutesFromNow)
                scheduleTimerIfNeeded()
            }
            self.timeToSleep = newTime
        }

        func scheduleTimerIfNeeded() {
            self.queue.asyncAfter(deadline: DispatchTime.now() + 1) {
                checkTimerStateAndScheduleNextRun()
            }
        }

        func checkTimerStateAndScheduleNextRun() {
            if let tts = self.timeToSleep, self.trigger != .never {
                let now = Date()
                if now.compare(tts) == ComparisonResult.orderedDescending {
                    DispatchQueue.main.async { [weak self] () -> Void in
                        self?.player.pause()
                    }
                    self.clearTriggers()
                } else {
                    scheduleTimerIfNeeded()
                }
            }
        }

        self.trigger = trigger
        let minutes: (_ timeInterval: TimeInterval) -> TimeInterval = { $0 * 60 }
        switch self.trigger {
        case .never, .endOfChapter:
            timeToSleepIn(nil)
        case .fifteenMinutes:
            timeToSleepIn(minutes(15))
        case .thirtyMinutes:
            timeToSleepIn(minutes(30))
        case .oneHour:
            timeToSleepIn(minutes(60))
        }
    }

    private func clearTriggers() {
        self.trigger = .never
        self.timeToSleep = nil
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
            self.queue.async { [weak self] in
                self?.clearTriggers()
            }
        }
    }
}


