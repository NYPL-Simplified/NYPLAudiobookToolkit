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
        let cursor = Cursor(data: data, index: 0)?.next()
        XCTAssertNotNil(cursor)
        XCTAssertEqual(cursor!.currentElement, 1)
    }

    func testNextItemFails() {
        let data: [Int] = [0, 1, 2]
        let cursor = Cursor(data: data, index: 2)?.next()
        XCTAssertNil(cursor)
    }

    func testPrevItem() {
        let data: [Int] = [0, 1, 2]
        let cursor = Cursor(data: data, index: 1)?.prev()
        XCTAssertNotNil(cursor)
        XCTAssertEqual(cursor!.currentElement, 0)
    }

    func testPrevItemFails() {
        let data: [Int] = [0, 1, 2]
        let cursor = Cursor(data: data, index: 0)?.prev()
        XCTAssertNil(cursor)
    }
}
