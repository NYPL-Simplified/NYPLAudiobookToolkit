//
//  CoreTests.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Ettore Pasquini on 1/5/22.
//  Copyright © 2022 Dean Silfen. All rights reserved.
//

import XCTest
@testable import NYPLAudiobookToolkit

class CoreTests: XCTestCase {
    func testAudiobookToolkitBundle() {
        XCTAssertNotNil(Bundle.audiobookToolkit())
    }
}
