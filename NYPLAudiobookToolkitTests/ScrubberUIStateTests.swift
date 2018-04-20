//
//  ScrubberUIStateTests.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import XCTest
@testable import NYPLAudiobookToolkit

class ScrubberUIStateTests: XCTestCase {
    
    func testProgressLocationFor() {
        let state = ScrubberUIState(
            gripperHeight: 10,
            progressColor: UIColor.black,
            progress: ScrubberProgress(
                offset: 5,
                duration: 10,
                timeLeftInBook: 10
            ),
            middleText: "some Text",
            scrubbing: true
        )
        let widthOfProgress = state.progressLocationFor(100)
        XCTAssertEqual(widthOfProgress, 50)
    }
}
