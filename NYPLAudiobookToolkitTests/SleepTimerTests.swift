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
}
