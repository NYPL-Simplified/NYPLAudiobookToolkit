//
//  ScrubberProgressTests.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import XCTest
@testable import NYPLAudiobookToolkit

class ScrubberProgressTests: XCTestCase {
    func testProgressFromPrecentage() {
        let scrubberProgress = ScrubberProgress(offset: 0, duration: 10, timeLeftInBook: 10)
        let halfWayThrough = scrubberProgress.progressFromPrecentage(0.5)
        XCTAssertEqual(halfWayThrough.offset, 5)
        XCTAssertEqual(halfWayThrough.duration, 10)
        XCTAssertEqual(halfWayThrough.timeLeftInBook, 5)
    }
}
