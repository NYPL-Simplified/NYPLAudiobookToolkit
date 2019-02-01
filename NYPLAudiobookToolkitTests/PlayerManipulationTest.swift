//
//  PlayerManipulationTest.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 4/18/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import XCTest
@testable import NYPLAudiobookToolkit

class PlayerManipulationTest: XCTestCase {

    func testDestinationInCurrentChapter() {
        let spine = mockSpine(numberOfChapters: 1)
        let cursor = Cursor<SpineElement>(data: spine)!
        let destination = spine.first!.chapter
        let playhead = move(cursor: cursor, to: destination)
        let playheadLocationIsEqualToChapter = playhead.location.inSameChapter(other: destination)
        XCTAssertTrue(playheadLocationIsEqualToChapter, "Attempted to move playhead within chapter, but got a new chapter instead")
    }

    func testSeekIntoNextChapter() {
        let duration = TimeInterval(10)
        let spine = self.mockSpine(numberOfChapters: 3, duration: duration)
        let cursor = Cursor<SpineElement>(data: spine)!
        let chapter1 = spine[0].chapter
        let chapter2 = spine[1].chapter
        
        // we seek 5 seconds into the second chapter from the first
        let destination = chapter1.update(playheadOffset: duration + 5)!
        let playhead = move(cursor: cursor, to: destination)

        let newDestinationIsInChapter2 = playhead.location.inSameChapter(other: chapter2)
        XCTAssertTrue(
            newDestinationIsInChapter2,
            "Attempted to move playhead into next chapter, but playhead was not found in the next chapter"
        )
    }

    func testSeekIntoPrevChapter() {
        let duration = TimeInterval(10)
        let spine = self.mockSpine(numberOfChapters: 3, duration: duration)
        let cursor = Cursor<SpineElement>(data: spine)!
        let chapter1 = spine[0].chapter
        let chapter2 = spine[1].chapter
        
        // we seek 5 seconds into the first chapter from the second
        let destination = chapter2.update(playheadOffset: -5)!
        let playhead = move(cursor: cursor, to: destination)
        
        let newDestinationIsInNewChapter = playhead.location.inSameChapter(other: chapter1)
        XCTAssertTrue(
            newDestinationIsInNewChapter,
            "Attempted to move playhead into next chapter, but playhead was not found in the next chapter"
        )
    }

    func testSeekToStartOfNextChapter() {
        let duration = TimeInterval(10)
        let spine = self.mockSpine(numberOfChapters: 3, duration: duration)
        let cursor = Cursor<SpineElement>(data: spine)!
        let chapter2 = spine[1].chapter

        // Seek to a point that does not exist in chapter 2
        let destination = chapter2.update(playheadOffset: 100)!
        let playhead = move(cursor: cursor, to: destination)

        let newDestinationIsInNextChapter = playhead.location.inSameChapter(other: chapter2)
        XCTAssertTrue(
            newDestinationIsInNextChapter,
            "Attempted to move playhead into next chapter, but playhead was not found in the next chapter"
        )
        XCTAssertTrue(
            playhead.location.playheadOffset == 0,
            "Attempted to move playhead to start of next chapter, but playhead was not at 0"
        )
    }

    func testSeekToStartOfPrevChapter() {
        let duration = TimeInterval(10)
        let spine = self.mockSpine(numberOfChapters: 3, duration: duration)
        let cursor = Cursor<SpineElement>(data: spine, index: 1)!
        let chapter1 = spine[0].chapter

        // Seek to a point that does not exist in chapter 1
        let destination = chapter1.update(playheadOffset: -100)!
        let playhead = move(cursor: cursor, to: destination)

        let newDestinationIsInPrevChapter = playhead.location.inSameChapter(other: chapter1)
        XCTAssertTrue(
            newDestinationIsInPrevChapter,
            "Attempted to move playhead into next chapter, but playhead was not found in the next chapter"
        )
        XCTAssertTrue(
            playhead.location.playheadOffset == 0,
            "Attempted to move playhead to start of next chapter, but playhead was not at 0"
        )
    }

    func mockSpine(numberOfChapters: Int, duration: TimeInterval = 10) -> [SpineElement] {
        let fakeDownloadTask = DownloadTaskMock(progress: Float(NSNotFound), key: "Does Not Matter", fetchClosure: nil)
        var mockElements: [SpineElement] = []
        for i in 1...numberOfChapters {
            let chapter = ChapterLocation(
                number: UInt(i),
                part: 1,
                duration: duration,
                startOffset: 0,
                playheadOffset: 0,
                title: "title",
                audiobookID: "somebook"
            )!
            let mock = SpineElementMock(key: "something\(i)", downloadTask: fakeDownloadTask, chapter: chapter)
            mockElements.append(mock)
        }
        return mockElements
    }
}
