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
        let playhead = moveCursor(to: destination, cursor: cursor)
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
        let destination = chapter1.chapterWith(duration + 5)!
        let playhead = moveCursor(to: destination, cursor: cursor)
        let newDestinationIsNoLongerInChapter1 = playhead.location.inSameChapter(other: chapter1)
        XCTAssertFalse(
            newDestinationIsNoLongerInChapter1,
            "Attempted to move playhead into next chapter, but playhead is still in current chapter"
        )

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
        let destination = chapter2.chapterWith(-5)!
        let playhead = moveCursor(to: destination, cursor: cursor)
        let newDestinationIsNoLongerInPreviousChapter = playhead.location.inSameChapter(other: chapter2)
        XCTAssertFalse(
            newDestinationIsNoLongerInPreviousChapter,
            "Attempted to move playhead into next chapter, but playhead is still in current chapter"
        )
        
        let newDestinationIsInNewChapter = playhead.location.inSameChapter(other: chapter1)
        XCTAssertTrue(
            newDestinationIsInNewChapter,
            "Attempted to move playhead into next chapter, but playhead was not found in the next chapter"
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
