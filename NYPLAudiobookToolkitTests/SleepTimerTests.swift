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
        XCTAssertFalse(sleepTimer.isScheduled)
        sleepTimer.setTimerTo(trigger: .fifteenMinutes)
        XCTAssertTrue(sleepTimer.isScheduled)
    }
    
    func testCancelSchedule() {
        let sleepTimer = SleepTimer(player: PlayerMock())
        sleepTimer.setTimerTo(trigger: .thirtyMinutes)
        XCTAssertTrue(sleepTimer.isScheduled)
        sleepTimer.cancel()
        XCTAssertFalse(sleepTimer.isScheduled)
        XCTAssertEqual(sleepTimer.timeRemaining, 0)
    }
    
    func testTestEndOfChapter() {
        let duration = TimeInterval(60)
        let chapter = ChapterLocation(
            number: 1,
            part: 0,
            duration: duration,
            startOffset: 0,
            playheadOffset: 0,
            title: "Sometime"
        )
        let sleepTimer = SleepTimer(player: PlayerMock(currentChapter: chapter))
        sleepTimer.setTimerTo(trigger: .endOfChapter)
        XCTAssertTrue(sleepTimer.isScheduled)
    }

    func testTimeDecreases() {
        let expectTimeToDecrease = expectation(description: "time to decrease")
        let sleepTimer = SleepTimer(player: PlayerMock())
        sleepTimer.setTimerTo(trigger: .fifteenMinutes)
        let fourteenMinutesAndFiftyEightSeconds: TimeInterval = (60 * 14) + 58
        self.asyncCheckFor(
            sleepTimer: sleepTimer,
            untilTime: fourteenMinutesAndFiftyEightSeconds,
            theExpectation: expectTimeToDecrease
        )
        wait(for: [expectTimeToDecrease], timeout: 4)
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
