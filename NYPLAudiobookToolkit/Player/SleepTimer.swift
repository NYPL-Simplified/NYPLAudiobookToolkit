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

private enum TimerState {
    case inactive
    case playing(until: Date)
    case paused(remaining: TimeInterval)
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
            case .endOfChapter, .fifteenMinutes, .thirtyMinutes, .oneHour:
                switch self.timerState {
                case .paused(let remaining):
                    timeRemaining = remaining
                case .playing(let until):
                    timeRemaining = abs(Date().timeIntervalSince(until))
                case .inactive:
                    break
                }
            }
        }
        return timeRemaining
    }
    
    /// We only want to count down the sleep timer
    /// while content is playing. This value keeps
    /// track of weather the timer "playing" and
    /// should be counting down until it terminates
    /// playback, or if it is "paused" and should
    /// record the time remaining in the timer
    private var timerState: TimerState = .inactive

    /// The type of trigger, determines if the timer is active
    /// and if the pause will come from a specific time,
    /// or the conclusion of a chapter. This specifies
    /// when the consumer would like the the timer to
    /// stop playback.
    private(set) var trigger: SleepTimerTriggerAt = .never

    /// Start a timer for a specific amount of time.
    public func setTimerTo(trigger: SleepTimerTriggerAt) {
        self.queue.sync {
            self.update(trigger: trigger)
        }
    }

    private func update(trigger: SleepTimerTriggerAt) {
        func timeToSleepIn(_ minutesFromNow: TimeInterval?) {
            guard let minutesFromNow = minutesFromNow else {
                self.clearState()
                return
            }
            if self.player.isPlaying {
                self.timerState = .playing(until: Date().addingTimeInterval(minutesFromNow))
            } else {
                self.timerState = .paused(remaining: minutesFromNow)
            }
            scheduleTimerIfNeeded()
        }

        func scheduleTimerIfNeeded() {
            self.queue.asyncAfter(deadline: DispatchTime.now() + 1) {
                checkTimerStateAndScheduleNextRun()
            }
        }

        func checkTimerStateAndScheduleNextRun() {
            guard self.trigger != .never else {
                return
            }

            switch self.timerState {
            case .paused(_):
                scheduleTimerIfNeeded()
            case .playing(let until):
                let now = Date()
                if now.compare(until) == ComparisonResult.orderedDescending {
                    DispatchQueue.main.async { [weak self] () -> Void in
                        self?.player.pause()
                    }
                    self.clearState()
                } else {
                    scheduleTimerIfNeeded()
                }
            default:
                self.clearState()
            }
        }

        self.trigger = trigger
        let minutes: (_ timeInterval: TimeInterval) -> TimeInterval = { $0 * 60 }
        switch self.trigger {
        case .never:
            timeToSleepIn(nil)
        case .endOfChapter:
            timeToSleepIn(self.player.currentChapterLocation?.timeRemaining)
        case .fifteenMinutes:
            timeToSleepIn(minutes(15))
        case .thirtyMinutes:
            timeToSleepIn(minutes(30))
        case .oneHour:
            timeToSleepIn(minutes(60))
        }
    }

    private func clearState() {
        self.trigger = .never
        self.timerState = .inactive
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
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        switch self.timerState {
        case .paused(let remaining):
            self.timerState = .playing(until: Date().addingTimeInterval(remaining))
        case .playing(_):
            if self.trigger == .endOfChapter {
                self.timerState = .playing(until: Date().addingTimeInterval(abs(chapter.timeRemaining)))
            }
        default:
            break
        }
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        switch self.timerState {
        case .playing(let until):
            let timeLeft = Date().timeIntervalSince(until)
            if timeLeft < 0 {
                let newState: TimerState
                if self.trigger == .endOfChapter {
                    // We need to special case .endOfChapter to ensure timeRemaining is
                    // consistent with other timers on the screen.
                    // The math should work out to the same values, but timeRemaining
                    // ensures consistency.
                    newState = .paused(remaining: abs(chapter.timeRemaining))
                } else {
                    newState = .paused(remaining: abs(timeLeft))
                }
                self.timerState = newState
            }
        default:
            break
        }
    }
}


