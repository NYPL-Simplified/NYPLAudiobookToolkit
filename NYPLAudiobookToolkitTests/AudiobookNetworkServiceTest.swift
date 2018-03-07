//
//  AudiobookNetworkService.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/5/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import XCTest
@testable import NYPLAudiobookToolkit

class RetryAfterErrorAudiobookNetworkServiceDelegate: AudiobookNetworkServiceDelegate {
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) { }
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement) { }
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement) { }
    
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError, for spineElement: SpineElement) {
        audiobookNetworkService.fetch()
    }
}

class AudiobookNetworkServiceTest: XCTestCase {
    
    func testDownloadProgressWithEmptySpine() {
        let service = DefaultAudiobookNetworkService(spine: [])
        XCTAssertEqual(service.downloadProgress, 0)
    }
    
    func testDownloadProgressWithTwoSpineElements() {
        let task1 = DownloadTaskMock(progress: 0.50, key: "http://chap1", fetchClosure: nil)
        let chapter1 = ChapterLocation(number: 1, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The Start")!
        let spine1 = SpineElementMock(key: task1.key, downloadTask: task1, chapter: chapter1)

        let task2 = DownloadTaskMock(progress: 0.25, key: "http://chap2", fetchClosure: nil)
        let chapter2 = ChapterLocation(number: 2, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The End")!
        let spine2 = SpineElementMock(key: task2.key, downloadTask: task2, chapter: chapter2)

        let service = DefaultAudiobookNetworkService(spine: [spine1, spine2])
        XCTAssertEqual(service.downloadProgress, 0.375, accuracy: 0.001)
    }

    func testDownloadInSerialOrder() {
        let expectTask1ToFetch = expectation(description: "Task 1 was fetched")
        let fetchClosureForTask1 = { (task: DownloadTask) -> Void in
            expectTask1ToFetch.fulfill()
            task.delegate?.downloadTaskReadyForPlayback(task)
        }
    
        let expectTask2ToFetch = expectation(description: "Task 2 was fetched")
        let fetchClosureForTask2 = { (task: DownloadTask) -> Void in
            expectTask2ToFetch.fulfill()
            task.delegate?.downloadTaskReadyForPlayback(task)
        }

        let task1 = DownloadTaskMock(progress: 0, key: "http://chap1", fetchClosure: fetchClosureForTask1)
        let chapter1 = ChapterLocation(number: 1, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The Start")!
        let spine1 = SpineElementMock(key: task1.key, downloadTask: task1, chapter: chapter1)
    
        let task2 = DownloadTaskMock(progress: 0, key: "http://chap2", fetchClosure: fetchClosureForTask2)
        let chapter2 = ChapterLocation(number: 2, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The End")!
        let spine2 = SpineElementMock(key: task2.key, downloadTask: task2, chapter: chapter2)

        let service = DefaultAudiobookNetworkService(spine: [spine1, spine2])
        
        service.fetch()
        wait(for: [expectTask1ToFetch, expectTask2ToFetch], timeout: 5, enforceOrder: true)
    }

    func testFetchAttemptsEveryFile() {
        var shouldFail = true
        let expectTask1ToFetchFirstTime = expectation(
            description: "Task 1 was fetched once"
        )
        let expectTask1ToFetchSecondTime = expectation(
            description: "Task 1 was fetched twice"
        )
        let fetchClosureForTask1 = { (task: DownloadTask) -> Void in
            if shouldFail {
                expectTask1ToFetchFirstTime.fulfill()
            } else {
                expectTask1ToFetchSecondTime.fulfill()
            }
            task.delegate?.downloadTaskReadyForPlayback(task)
        }
        
        let expectTask2ToFail = expectation(description: "Task 2 hit an error")
        let expectTask2ToFetch = expectation(description: "Task 2 was fetched")
        let fetchClosureForTask2 = { (task: DownloadTask) -> Void in
            if shouldFail {
                shouldFail = false
                expectTask2ToFail.fulfill()
                task.delegate?.downloadTask(task, didReceive: NSError())
            } else {
                expectTask2ToFetch.fulfill()
                task.delegate?.downloadTaskReadyForPlayback(task)
            }
        }

        let expectTask3ToFetch = expectation(description: "Task 3 was fetched")
        let fetchClosureForTask3 = { (task: DownloadTask) -> Void in
            expectTask3ToFetch.fulfill()
            task.delegate?.downloadTaskReadyForPlayback(task)
        }

        let task1 = DownloadTaskMock(progress: 0, key: "http://chap1", fetchClosure: fetchClosureForTask1)
        let chapter1 = ChapterLocation(number: 1, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The Start")!
        let spine1 = SpineElementMock(key: task1.key, downloadTask: task1, chapter: chapter1)
        
        let task2 = DownloadTaskMock(progress: 0, key: "http://chap2", fetchClosure: fetchClosureForTask2)
        let chapter2 = ChapterLocation(number: 2, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The Middle")!
        let spine2 = SpineElementMock(key: task2.key, downloadTask: task2, chapter: chapter2)
        
        let task3 = DownloadTaskMock(progress: 0, key: "http://chap2", fetchClosure: fetchClosureForTask3)
        let chapter3 = ChapterLocation(number: 3, part: 0, duration: 10, startOffset: 0, playheadOffset: 0, title: "The End")!
        let spine3 = SpineElementMock(key: task3.key, downloadTask: task3, chapter: chapter3)
        
        let service = DefaultAudiobookNetworkService(spine: [spine1, spine2, spine3])
        let serviceDelegate = RetryAfterErrorAudiobookNetworkServiceDelegate()
        service.registerDelegate(serviceDelegate)
        service.fetch()

        wait(for: [
            expectTask1ToFetchFirstTime,
            expectTask2ToFail,
            expectTask1ToFetchSecondTime,
            expectTask2ToFetch,
            expectTask3ToFetch
        ], timeout: 10, enforceOrder: true)
    }
}
