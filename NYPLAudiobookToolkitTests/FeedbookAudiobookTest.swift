import Foundation
import XCTest
@testable import NYPLAudiobookToolkit

class FeedbookAudiobookTest: XCTestCase {
  
  // TODO: Populate with actual profile data to test
  let feedbookJsonTimeExpired = """
  """
  
  // TODO: Populate with actual profile data to test
  let feedbookJson = """
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
  }

  func testFeedBookTimeExpired() {
    let feedbookData = feedbookJsonTimeExpired.data(using: .utf8)
    guard let feedbookObj = try! JSONSerialization.jsonObject(with: feedbookData!, options: []) as? [String: Any] else {
      XCTAssert(false, "Error parsing feedbook data")
      return
    }

    XCTAssertNil(AudiobookFactory.audiobook(feedbookObj) , "AudiobookFactory should return nil for expired book")
  }
  
  func testFeedBook() {
    let feedbookData = feedbookJson.data(using: .utf8)
    guard let feedbookObj = try! JSONSerialization.jsonObject(with: feedbookData!, options: []) as? [String: Any] else {
      XCTAssert(false, "Error parsing feedbook data")
      return
    }
    
    guard let feedbookAudiobook = AudiobookFactory.audiobook(feedbookObj) else {
      XCTAssert(false, "AudiobookFactory returned nil")
      return
    }
    
    feedbookAudiobook.deleteLocalContent()
    
    guard let firstSpineItem = feedbookAudiobook.spine.first else {
      XCTAssert(false, "Expected first spine item element to exist")
      return
    }

    let delegate = TestFeedbookDownloadTaskDelegate()
    firstSpineItem.downloadTask.delegate = delegate
    firstSpineItem.downloadTask.fetch()
    let startTime = Date.init(timeIntervalSinceNow: 0)
    while !delegate.finished && startTime.timeIntervalSinceNow > -(60) { // One minute timeout
      Thread.sleep(forTimeInterval: 2)
    }
    XCTAssert(delegate.finished, "Timed out")
    XCTAssert(!delegate.failed, "Download failed")
  }
}
