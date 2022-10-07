//
//  NYPLAudiobookBookmarkFactoryTests.swift
//  
//
//  Created by Ernest Fan on 2022-10-05.
//

import XCTest
import NYPLUtilities
@testable import NYPLAudiobookToolkit

class NYPLAudiobookBookmarkFactoryTests: XCTestCase {
  var bundle: Bundle!

  override func setUpWithError() throws {
    bundle = Bundle(for: NYPLAudiobookBookmarkFactoryTests.self)
  }

  override func tearDownWithError() throws {
    bundle = nil
  }

  func testMakeAudiobookBookmarkFromServerAnnotation() throws {
    let locatorURL = Bundle.module.url(forResource: "valid-bookmark-4", withExtension: "json")!
    let locatorData = try Data(contentsOf: locatorURL)
    let json = try JSONSerialization.jsonObject(with: locatorData) as! [String: Any]
    guard let bookmark = NYPLAudiobookBookmarkFactory.make(fromServerAnnotation: json,
                                                           selectorValueParser: NYPLBookmarkSelectorParserMock.self,
                                                           annotationType: .readingProgress,
                                                           bookID: "urn:uuid:1daa8de6-94e8-4711-b7d1-e43b572aa6e0") else {
      XCTFail("Failed to create bookmark")
      return
    }
    
    XCTAssertEqual(bookmark.annotationId, "urn:uuid:715885bc-23d3-4d7d-bd87-f5e7a042c4ba")
    XCTAssertEqual(bookmark.title, "Chapter title")
    XCTAssertEqual(bookmark.part, 3)
    XCTAssertEqual(bookmark.chapter, 32)
    XCTAssertEqual(bookmark.duration, TimeInterval(190000))
    XCTAssertEqual(bookmark.time, TimeInterval(78000))
    XCTAssertEqual(bookmark.audiobookId, "urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03")
  }
  
  func testMakeAudiobookBookmarkFromServerAnnotationWithInvalidValue() throws {
    // The negative duration and time should be corrected when audiobook bookmark being created
    let locatorURL = Bundle.module.url(forResource: "valid-bookmark-4", withExtension: "json")!
    let locatorData = try Data(contentsOf: locatorURL)
    let json = try JSONSerialization.jsonObject(with: locatorData) as! [String: Any]
    
    NYPLBookmarkSelectorParserMock.returnInvalidData = true
    
    guard let bookmark = NYPLAudiobookBookmarkFactory.make(fromServerAnnotation: json,
                                                           selectorValueParser: NYPLBookmarkSelectorParserMock.self,
                                                           annotationType: .readingProgress,
                                                           bookID: "urn:uuid:1daa8de6-94e8-4711-b7d1-e43b572aa6e0") else {
      XCTFail("Failed to create bookmark")
      return
    }
    
    NYPLBookmarkSelectorParserMock.returnInvalidData = false
    
    XCTAssertEqual(bookmark.annotationId, "urn:uuid:715885bc-23d3-4d7d-bd87-f5e7a042c4ba")
    XCTAssertEqual(bookmark.title, "Chapter title")
    XCTAssertEqual(bookmark.part, 3)
    XCTAssertEqual(bookmark.chapter, 32)
    XCTAssertEqual(bookmark.duration, TimeInterval(0))
    XCTAssertEqual(bookmark.time, TimeInterval(0))
    XCTAssertEqual(bookmark.audiobookId, "urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03")
  }
  
  func testParseLocatorString() throws {
    guard let LocatorString = NYPLBookmarkSelectorParserMock.parseSelectorJSONString(fromServerAnnotation: [:],
                                                                                      annotationType: .bookmark,
                                                                                      bookID: ""),
          let selectorValue = NYPLAudiobookBookmarkFactory.parseLocatorString(LocatorString) else {
      XCTFail("Failed to parse value from sample selector string in NYPLBookmarkSelectorParserMock")
      return
    }
    
    XCTAssertEqual(selectorValue.title, "Chapter title")
    XCTAssertEqual(selectorValue.part, 3)
    XCTAssertEqual(selectorValue.chapter, 32)
    XCTAssertEqual(selectorValue.duration, TimeInterval(190000))
    XCTAssertEqual(selectorValue.time, TimeInterval(78000))
    XCTAssertEqual(selectorValue.audiobookId, "urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03")
  }
  
  func testParseInvalidLocatorString() throws {
    // Negative part
    let invalidLocatorStringWithNegativePart = "{\n \"@type\": \"LocatorAudioBookTime\",\n \"part\": -3,\n  \"chapter\": 32,\n  \"title\": \"Chapter title\",\n  \"audiobookID\": \"urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03\",\n \"duration\": 190000,\n  \"time\": 78000}\n"
    
    XCTAssertNil(NYPLAudiobookBookmarkFactory.parseLocatorString(invalidLocatorStringWithNegativePart), "Selector with negative part value should return nil")
    
    // Negative chapter
    let invalidLocatorStringWithNegativeChapter = "{\n \"@type\": \"LocatorAudioBookTime\",\n \"part\": 3,\n  \"chapter\": -32,\n  \"title\": \"Chapter title\",\n  \"audiobookID\": \"urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03\",\n \"duration\": 190000,\n  \"time\": 78000}\n"
    
    XCTAssertNil(NYPLAudiobookBookmarkFactory.parseLocatorString(invalidLocatorStringWithNegativeChapter), "Selector with negative chapter value should return nil")
    
    // Empty duration
    let invalidLocatorStringWithEmptyDuration = "{\n \"@type\": \"LocatorAudioBookTime\",\n \"part\": 3,\n  \"chapter\": 32,\n  \"title\": \"Chapter title\",\n  \"audiobookID\": \"urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03\",\n \"duration\": ,\n  \"time\": 78000}\n"
    
    XCTAssertNil(NYPLAudiobookBookmarkFactory.parseLocatorString(invalidLocatorStringWithEmptyDuration), "Selector with empty duration value should return nil")
    
    // Empty time
    let invalidLocatorStringWithEmptyTime = "{\n \"@type\": \"LocatorAudioBookTime\",\n \"part\": 3,\n  \"chapter\": 32,\n  \"title\": \"Chapter title\",\n  \"audiobookID\": \"urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03\",\n \"duration\": 190000,\n  \"time\":}\n"
    
    XCTAssertNil(NYPLAudiobookBookmarkFactory.parseLocatorString(invalidLocatorStringWithEmptyTime), "Selector with empty time value should return nil")
    
    // Empty audiobook id
    let invalidLocatorStringWithEmptyAudiobookID = "{\n \"@type\": \"LocatorAudioBookTime\",\n \"part\": 3,\n  \"chapter\": 32,\n  \"title\": \"Chapter title\",\n  \"audiobookID\": \"\",\n \"duration\": 190000,\n  \"time\": -78000}\n"
    
    XCTAssertNil(NYPLAudiobookBookmarkFactory.parseLocatorString(invalidLocatorStringWithEmptyAudiobookID), "Selector with empty audiobook id should return nil")
  }
  
  func testLocatorStringRoundTrip() throws {
    let locatorString = NYPLAudiobookBookmarkFactory.makeLocatorString(title: "title",
                                                                       part: 1,
                                                                       chapter: 10,
                                                                       audiobookId: "urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03",
                                                                       duration: 15000,
                                                                       time: 3300)
    
    guard let selectorValue = NYPLAudiobookBookmarkFactory.parseLocatorString(locatorString) else {
      XCTFail("Failed to parse value from selector string")
      return
    }
    
    XCTAssertEqual(selectorValue.title, "title")
    XCTAssertEqual(selectorValue.part, 1)
    XCTAssertEqual(selectorValue.chapter, 10)
    XCTAssertEqual(selectorValue.duration, TimeInterval(15000))
    XCTAssertEqual(selectorValue.time, TimeInterval(3300))
    XCTAssertEqual(selectorValue.audiobookId, "urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03")
  }
  
  func testLocatorStringRoundTripWithInvalidValue() throws {
    // The `makeLocatorString` function should perform correction if incorrect values are provided
    let locatorString = NYPLAudiobookBookmarkFactory.makeLocatorString(title: "title",
                                                                       part: 1,
                                                                       chapter: 10,
                                                                       audiobookId: "urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03",
                                                                       duration: -15000,
                                                                       time: -3300)
    
    guard let selectorValue = NYPLAudiobookBookmarkFactory.parseLocatorString(locatorString) else {
      XCTFail("Failed to parse value from selector string")
      return
    }
    
    XCTAssertEqual(selectorValue.title, "title")
    XCTAssertEqual(selectorValue.part, 1)
    XCTAssertEqual(selectorValue.chapter, 10)
    XCTAssertEqual(selectorValue.duration, TimeInterval(0))
    XCTAssertEqual(selectorValue.time, TimeInterval(0))
    XCTAssertEqual(selectorValue.audiobookId, "urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03")
  }
}
