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

    public var timeRemaining: TimeInterval {
        var timeRemaining = TimeInterval(0)
        self.queue.sync { [weak self] () -> Void in
            if let strongSelf = self {
                switch strongSelf.trigger {
                case .never:
                    break
                case .endOfChapter:
                    let playHead = strongSelf.player.currentChapterLocation?.playheadOffset ?? 0
                    let duration = strongSelf.player.currentChapterLocation?.duration ?? 0
                    timeRemaining = duration - playHead
                case .fifteenMinutes, .thirtyMinutes, .oneHour:
                    if let tts = strongSelf.timeToSleep {
                        timeRemaining = abs(Date().timeIntervalSince(tts))
                    }
                }
            }
        }
        return timeRemaining
    }

    private var timeToSleep: Date?
    private var trigger: SleepTimerTriggerAt = .never
    public func cancel() {
        self.queue.sync {  [weak self] () -> Void in
            self?.trigger = .never
            self?.timeToSleep = nil
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
            self.timeToSleep = Date().addingTimeInterval(minutes(15))
        case .thirtyMinutes:
            self.timeToSleep = Date().addingTimeInterval(minutes(30))
        case .oneHour:
            self.timeToSleep = Date().addingTimeInterval(minutes(60))
        default:
            self.timeToSleep = nil
        }
        self.scheduleTimerIfNeeded()
    }

    private func scheduleTimerIfNeeded() {
        self.queue.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] () -> Void in
            self?.checkTimerStateAndScheduleNextRun()
        }
    }
    
    private func checkTimerStateAndScheduleNextRun() {
        if let tts = self.timeToSleep, self.trigger != .never {
            let now = Date()
            if now.compare(tts) == ComparisonResult.orderedDescending {
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
                self.timeToSleep = nil
            }
        }
    }
}


