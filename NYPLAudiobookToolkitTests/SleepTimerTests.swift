//
//  SleepTimerTests.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/7/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import XCTest
@testable import NYPLAudiobookToolkit

class SleepTimerTests: XCTestCase {
    
    func testIsScheduled() {
        let sleepTimer = SleepTimer(player: PlayerMock())
        XCTAssertFalse(sleepTimer.isActive)
        sleepTimer.setTimerTo(trigger: .fifteenMinutes)
        XCTAssertTrue(sleepTimer.isActive)
    }
    
    func testCancelSchedule() {
        let sleepTimer = SleepTimer(player: PlayerMock())
        sleepTimer.setTimerTo(trigger: .thirtyMinutes)
        XCTAssertTrue(sleepTimer.isActive)
        XCTAssertNotEqual(sleepTimer.timeRemaining, 0)
        sleepTimer.setTimerTo(trigger: .never)
        XCTAssertFalse(sleepTimer.isActive)
        XCTAssertEqual(sleepTimer.timeRemaining, 0)
    }
    
    /// `.endOfChapter` works differently from other triggers.
    /// Instead of keeping track of the time, it simply listens to
    /// `Player` and waits for the player to report that the
    /// current chapter has finished.
    func testTestEndOfChapter() {
        let duration = TimeInterval(60)
        let chapter = ChapterLocation(
            number: 1,
            part: 0,
            duration: duration,
            startOffset: 0,
            playheadOffset: 0,
            title: "Sometime",
            audiobookID: "someID"
        )
        let sleepTimer = SleepTimer(player: PlayerMock(currentChapter: chapter)!)
        sleepTimer.setTimerTo(trigger: .endOfChapter)
        XCTAssertTrue(sleepTimer.isActive)
    }

    func testTimeDecreases() {
        let expectTimeToDecrease = expectation(description: "time to decrease")
        let player = PlayerMock()
        player.isPlaying = true
        let sleepTimer = SleepTimer(player: player)
        sleepTimer.setTimerTo(trigger: .fifteenMinutes)
        let fourteenMinutesAndFiftyEightSeconds: TimeInterval = (60 * 14) + 58
        self.asyncCheckFor(
            sleepTimer: sleepTimer,
            untilTime: fourteenMinutesAndFiftyEightSeconds,
            theExpectation: expectTimeToDecrease
        )
        wait(for: [expectTimeToDecrease], timeout: 4)
    }

    func testIsAbleToSetDifferentTimes() {
        let expectTimeToDecreaseFrom15Minutes = expectation(description: "time to decrease from 15 minutes")
        let player = PlayerMock()
        player.isPlaying = true
        let sleepTimer = SleepTimer(player: player)
        sleepTimer.setTimerTo(trigger: .fifteenMinutes)
        XCTAssert(sleepTimer.isActive)
        let fourteenMinutesAndFiftyEightSeconds: TimeInterval = (60 * 14) + 58
        self.asyncCheckFor(
            sleepTimer: sleepTimer,
            untilTime: fourteenMinutesAndFiftyEightSeconds,
            theExpectation: expectTimeToDecreaseFrom15Minutes
        )
        wait(for: [expectTimeToDecreaseFrom15Minutes], timeout: 4)
        sleepTimer.setTimerTo(trigger: .never)
        XCTAssertFalse(sleepTimer.isActive)
        XCTAssertEqual(sleepTimer.timeRemaining, 0)
        
        sleepTimer.setTimerTo(trigger: .oneHour)
        XCTAssert(sleepTimer.isActive)
        let expectTimeToDecreaseFrom59Minutes = expectation(description: "time to decrease from 15 minutes")
        let fiftyNineMinutesAndFiftyEightSeconds: TimeInterval = (60 * 59) + 58
        self.asyncCheckFor(
            sleepTimer: sleepTimer,
            untilTime: fiftyNineMinutesAndFiftyEightSeconds,
            theExpectation: expectTimeToDecreaseFrom59Minutes
        )
        wait(for: [expectTimeToDecreaseFrom59Minutes], timeout: 4)
    }
    
    func testOnlyCountsDownWhilePlaying() {
        let player = PlayerMock()
        player.isPlaying = false
        let sleepTimer = SleepTimer(player: player)
        sleepTimer.setTimerTo(trigger: .fifteenMinutes)
        XCTAssert(sleepTimer.isActive)
        Thread.sleep(until: Date().addingTimeInterval(2))
        XCTAssertEqual(sleepTimer.timeRemaining, 60 * 15)
    }

    func asyncCheckFor(sleepTimer: SleepTimer, untilTime time: TimeInterval, theExpectation: XCTestExpectation) {
        let tts = sleepTimer.timeRemaining
        if  tts < time  && tts > 0{
            theExpectation.fulfill()
        } else {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.asyncCheckFor(sleepTimer: sleepTimer, untilTime: time, theExpectation: theExpectation)
            }
        }
    }
}
