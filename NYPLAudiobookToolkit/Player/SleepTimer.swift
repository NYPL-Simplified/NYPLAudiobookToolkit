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

private enum TimerStopPoint {
    case date(date: Date)
    case endOfChapter(chapterLocation: ChapterLocation)
}

private enum TimerDurationLeft {
    case timeInterval(timeInterval: TimeInterval)
    case restOfChapter(chapterLocation: ChapterLocation)
}

private enum TimerState {
    case inactive
    case playing(until: TimerStopPoint)
    case paused(with: TimerDurationLeft)
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
    public var isActive: Bool {
        return self.queue.sync {
            switch self.timerState {
            case .inactive:
                return false
            case .playing,
                 .paused:
                return true
            }
        }
    }

    /// Time remaining until the book will be paused.
    public var timeRemaining: TimeInterval {
        return self.queue.sync {
            switch self.timerState {
            case .inactive:
                return TimeInterval()
            case .playing(until: .date(let date)):
                return date.timeIntervalSinceNow
            case .playing(until: .endOfChapter),
                 .paused(with: .restOfChapter):
                return self.player.currentChapterLocation?.timeRemaining ?? TimeInterval()
            case .paused(with: .timeInterval(let timeInterval)):
                return timeInterval
            }
        }
    }
    
    /// We only want to count down the sleep timer
    /// while content is playing. This value keeps
    /// track of whether the timer "playing" and
    /// should be counting down until it terminates
    /// playback, or if it is "paused" and should
    /// record the time remaining in the timer
    private var timerState: TimerState = .inactive {
        didSet {
            switch self.timerState {
            case .playing(until: .date):
                self.scheduleTimer()
            case .inactive,
                 .paused,
                 .playing(until: .endOfChapter):
                break
            }
        }
    }

    /// The timer should be scheduled whenever we are
    /// in a `self.timerState == .playing(.date(_))`
    /// state. This is handled automatically by the
    /// setter for `timerState`.
    private var timerScheduled: Bool = false

    /// Start a timer for a specific amount of time.
    public func setTimerTo(trigger: SleepTimerTriggerAt) {
        self.queue.sync {
            self.update(trigger: trigger)
        }
    }

    /// Should be called when the sleep timer has hit zero.
    private func goToSleep() {
        DispatchQueue.main.async { [weak self] () in
            self?.player.pause()
        }
        self.timerState = .inactive
    }

    private func scheduleTimer() {
        if !self.timerScheduled {
            self.timerScheduled = true
            self.queue.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] () in
                self?.checkTimerStateAndScheduleNextRun()
            }
        }
    }

    private func checkTimerStateAndScheduleNextRun() {
        self.timerScheduled = false
        switch self.timerState {
        case .inactive,
             .paused,
             .playing(until: .endOfChapter):
            break
        case .playing(until: .date(let date)):
            if date.timeIntervalSinceNow > 0 {
                scheduleTimer()
            } else {
                self.goToSleep()
            }
        }
    }

    private func update(trigger: SleepTimerTriggerAt) {
        func sleepIn(secondsFromNow: TimeInterval) {
            if self.player.isPlaying {
                self.timerState = .playing(until: .date(date: Date(timeIntervalSinceNow: secondsFromNow)))
            } else {
                self.timerState = .paused(with: .timeInterval(timeInterval: secondsFromNow))
            }
        }

        let minutes: (_ timeInterval: TimeInterval) -> TimeInterval = { $0 * 60 }
        switch trigger {
        case .never:
            self.timerState = .inactive
        case .fifteenMinutes:
            sleepIn(secondsFromNow: minutes(15))
        case .thirtyMinutes:
            sleepIn(secondsFromNow: minutes(30))
        case .oneHour:
            sleepIn(secondsFromNow: minutes(60))
        case .endOfChapter:
            if let currentChapter = self.player.currentChapterLocation {
                if self.player.isPlaying {
                    self.timerState = .playing(until: .endOfChapter(chapterLocation: currentChapter))
                } else {
                    self.timerState = .paused(with: .restOfChapter(chapterLocation: currentChapter))
                }
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
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.queue.sync {
            switch self.timerState {
            case .inactive,
                 .playing:
                break
            case .paused(with: .timeInterval(let timeInterval)):
                self.timerState = .playing(until: .date(date: Date(timeIntervalSinceNow: timeInterval)))
            case .paused(with: .restOfChapter):
                self.timerState = .playing(until: .endOfChapter(chapterLocation: chapter))
            }
        }
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.queue.sync {
            switch self.timerState {
            case .inactive,
                 .paused:
                break
            case .playing(until: .date(let date)):
                self.timerState = .paused(with: .timeInterval(timeInterval: date.timeIntervalSinceNow))
            case .playing(until: .endOfChapter):
                self.timerState = .paused(with: .restOfChapter(chapterLocation: chapter))
            }
        }
    }

    public func player(_ player: Player, didComplete chapter: ChapterLocation) {
        self.queue.sync {
            switch self.timerState {
            case .inactive,
                 .paused:
                break
            case  .playing(let until):
                switch until {
                case .date:
                    break
                case .endOfChapter(let chapterToSleepAt):
                    if chapterToSleepAt.inSameChapter(other: chapter) {
                        self.goToSleep()
                    }
                }
            }
        }
    }

    public func playerDidUnload(_ player: Player) { }
}


