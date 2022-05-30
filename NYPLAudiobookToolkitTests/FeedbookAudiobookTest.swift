import Foundation
import XCTest
@testable import NYPLAudiobookToolkit

class FeedbookAudiobookTest: XCTestCase {
  
  // TODO: Populate with actual profile data to test
  let feedbookJsonTimeExpired = """
  {
  }
  """
  
  // TODO: Populate with actual profile data to test
  let feedbookJson = """
  {
  }
  """
  
  class TestFeedbookDownloadTaskDelegate : DownloadTaskDelegate {
    public var failed = false
    public var finished = false
    
    func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
      finished = true
    }
    
    func downloadTaskDidDeleteAsset(_ downloadTask: DownloadTask) {
    }
    
    func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
    }
    
    func downloadTaskFailed(_ downloadTask: DownloadTask, withError error: NSError?) {
      finished = true
      failed = true
    }
    
    func downloadTaskExceededTimeLimit(_ downloadTask: DownloadTask, elapsedTime: Double) {
    }
  }

  func testFeedBookTimeExpired() {
    guard let feedbookData = feedbookJsonTimeExpired.data(using: .utf8) else {
      XCTFail("Nil feedbook data")
      return
    }

    guard let feedbookJsonObj = try? JSONSerialization.jsonObject(with: feedbookData, options: []) else {
      XCTFail("Error parsing feedbook data")
      return
    }

    guard let feedbookObj = feedbookJsonObj as? [String: Any] else {
      XCTFail("Error casting jsonObject to Dictionary")
      return
    }

    XCTAssertNil(AudiobookFactory.audiobook(feedbookObj) , "AudiobookFactory should return nil for expired book")
  }

  // This test is disabled until we populate `feedbookJson` with some json data
//  func testFeedBook() {
//    guard let feedbookData = feedbookJson.data(using: .utf8) else {
//      XCTFail("Nil feedbook data")
//      return
//    }
//
//    guard let feedbookObj = try? JSONSerialization.jsonObject(with: feedbookData, options: []) as? [String: Any] else {
//      XCTFail("Error parsing feedbook data")
//      return
//    }
//    
//    guard let feedbookAudiobook = AudiobookFactory.audiobook(feedbookObj) else {
//      XCTFail("AudiobookFactory returned nil")
//      return
//    }
//    
//    feedbookAudiobook.deleteLocalContent()
//    
//    guard let firstSpineItem = feedbookAudiobook.spine.first else {
//      XCTFail("Expected first spine item element to exist")
//      return
//    }
//
//    let delegate = TestFeedbookDownloadTaskDelegate()
//    firstSpineItem.downloadTask.delegate = delegate
//    firstSpineItem.downloadTask.fetch()
//    let startTime = Date.init(timeIntervalSinceNow: 0)
//    while !delegate.finished && startTime.timeIntervalSinceNow > -(60) { // One minute timeout
//      Thread.sleep(forTimeInterval: 2)
//    }
//    XCTAssert(delegate.finished, "Timed out")
//    XCTAssert(!delegate.failed, "Download failed")
//  }
}
