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
        sleepTimer.startTimerFor(trigger: .fifteenMinutes)
        XCTAssertTrue(sleepTimer.isScheduled)
    }
    
    func testCancelSchedule() {
        let sleepTimer = SleepTimer(player: PlayerMock())
        sleepTimer.startTimerFor(trigger: .thirtyMinutes)
        XCTAssertTrue(sleepTimer.isScheduled)
        sleepTimer.cancel()
        XCTAssertFalse(sleepTimer.isScheduled)
    }
    
    func testTimeDecreases() {
        let expectTimeToDecrease = expectation(description: "time to decrease")
        let sleepTimer = SleepTimer(player: PlayerMock())
        sleepTimer.startTimerFor(trigger: .fifteenMinutes)
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
        print("DEANDEBUG timeRemaining \(tts)")
        if  tts < time  && tts > 0{
            theExpectation.fulfill()
        } else {
            DispatchQueue.main.async { [weak self] () -> Void in
                self?.asyncCheckFor(sleepTimer: sleepTimer, untilTime: time, theExpectation: theExpectation)
            }
        }
    }
}
