import Foundation
import XCTest

@testable import NYPLAudiobookToolkit

fileprivate let emptyData = Data.init([])
fileprivate let int32 = Data.init( [0, 0, 0, 1])
fileprivate let int64 = Data.init([0, 0, 0, 0, 0, 0, 0, 1])
fileprivate let int32Offset1 = Data.init([255, 0, 0, 0, 1])
fileprivate let int64Offset1 = Data.init([255, 0, 0, 0, 0, 0, 0, 0, 1])

class DataBigEndianTest: XCTestCase {
  func testBigEndianUInt32() {
    var num: UInt32 = 0
    XCTAssertThrowsError(try emptyData.bigEndianUInt32())
    XCTAssertThrowsError(try int64.bigEndianUInt32())
    XCTAssertNoThrow(num = try int32.bigEndianUInt32())
    XCTAssertEqual(num, 1)
  }
    
  func testBigEndianUInt64() {
    var num: UInt64 = 0
    XCTAssertThrowsError(try emptyData.bigEndianUInt64())
    XCTAssertThrowsError(try int64Offset1.bigEndianUInt64())
    XCTAssertNoThrow(num = try int64.bigEndianUInt64())
    XCTAssertEqual(num, 1)
  }
    
  func testBigEndianUInt32Offset() {
    var num: UInt32 = 0
    XCTAssertThrowsError(try emptyData.bigEndianUInt32At(offset: 1))
    XCTAssertNoThrow(num = try int32Offset1.bigEndianUInt32At(offset: 1))
    XCTAssertEqual(num, 1)
    XCTAssertNoThrow(num = try int32.bigEndianUInt32At(offset: 0))
    XCTAssertEqual(num, 1)
  }
    
  func testBigEndianUInt64Offset() {
    var num: UInt64 = 0
    XCTAssertThrowsError(try emptyData.bigEndianUInt64At(offset: 1))
    XCTAssertNoThrow(num = try int64Offset1.bigEndianUInt64At(offset: 1))
    XCTAssertEqual(num, 1)
    XCTAssertNoThrow(num = try int64.bigEndianUInt64At(offset: 0))
    XCTAssertEqual(num, 1)
  }
}
