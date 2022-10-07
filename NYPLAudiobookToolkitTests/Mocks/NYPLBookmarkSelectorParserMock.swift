//
//  NYPLBookmarkSelectorParserMock.swift
//  
//
//  Created by Ernest Fan on 2022-10-05.
//

import Foundation
import NYPLUtilities

class NYPLBookmarkSelectorParserMock: NYPLBookmarkSelectorParsing {
  static var returnInvalidData = false
  
  static func parseSelectorJSONString(fromServerAnnotation annotation: [String: Any],
                                      annotationType: NYPLBookmarkSpec.Motivation,
                                      bookID: String) -> String? {
    // Return data with negative `duration` and `time`
    if returnInvalidData {
      return "{\n \"@type\": \"LocatorAudioBookTime\",\n \"part\": 3,\n  \"chapter\": 32,\n  \"title\": \"Chapter title\",\n  \"audiobookID\": \"urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03\",\n \"duration\": -190000,\n  \"time\": -78000}\n"
    }
    // Sample selector value from `valid-bookmark-4`
    return "{\n \"@type\": \"LocatorAudioBookTime\",\n \"part\": 3,\n  \"chapter\": 32,\n  \"title\": \"Chapter title\",\n  \"audiobookID\": \"urn:uuid:b309844e-7d4e-403e-945b-fbc78acd5e03\",\n \"duration\": 190000,\n  \"time\": 78000}\n"
  }
}
