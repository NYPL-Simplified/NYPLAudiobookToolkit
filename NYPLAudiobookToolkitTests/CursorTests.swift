//
//  CursorTests.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 2/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import XCTest
@testable import NYPLAudiobookToolkit

class CursorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testIndexOutOfBounds() {
        let data: [Int] = []
        let cursor = Cursor(data: data, index: 3)
        XCTAssertNil(cursor)
    }
    
    func testIndexTooLow() {
        let data: [Int] = []
        let cursor = Cursor(data: data, index: -3)
        XCTAssertNil(cursor)
    }

    func testIndexExists() {
        let data: [Int] = [0, 1, 2]
        let cursor = Cursor(data: data, index: 0)
        XCTAssertEqual(cursor?.currentElement, 0)
    }
    
    func testNextItem() {
        let data: [Int] = [0, 1, 2]
        let cursor = Cursor(data: data, index: 0)
        XCTAssertEqual(cursor?.next().currentElement, 1)
    }

    func testPrevItem() {
        let data: [Int] = [0, 1, 2]
        let cursor = Cursor(data: data, index: 1)
        XCTAssertEqual(cursor?.prev().currentElement, 0)
    }
}
