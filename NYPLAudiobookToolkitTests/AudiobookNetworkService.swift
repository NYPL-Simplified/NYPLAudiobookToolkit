//
//  AudiobookNetworkService.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/5/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import XCTest
import NYPLAudiobookToolkit

class AudiobookNetworkService: XCTestCase {
    
    func testDownloadProgressWithEmptySpine() {
        let service = DefaultAudiobookNetworkService(spine: [])
        XCTAssertEqual(service.downloadPercentage, 0)
    }
    
    func testDownloadProgressWithTwoSpineElements() {
        let task1 = DownloadTaskMock(progress: 0.50, key: "http://chap1")
        let chapter1 = ChapterLocation(number: 1, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The Start")!
        let spine1 = SpineElementMock(key: task1.key, downloadTask: task1, chapter: chapter1)

        let task2 = DownloadTaskMock(progress: 0.25, key: "http://chap1")
        let chapter2 = ChapterLocation(number: 2, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The Start")!
        let spine2 = SpineElementMock(key: task2.key, downloadTask: task2, chapter: chapter2)

        let service = DefaultAudiobookNetworkService(spine: [spine1, spine2])
        XCTAssertEqual(service.downloadPercentage, 0.375, accuracy: 0.001)
    }
}
