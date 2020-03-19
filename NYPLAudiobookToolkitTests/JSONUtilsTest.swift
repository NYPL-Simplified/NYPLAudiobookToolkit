import Foundation
import XCTest

@testable import NYPLAudiobookToolkit

class JSONUtilsTest: XCTestCase {
    let obj1: [String: Any?] = [
        "stringKey": "stringValue",
        "intKey": 1,
        "floatKey": 123.123,
        "boolKey": true,
        "arrayKey": [
            -0.1,
            false,
            0.002,
            -123,
            -123.123,
            [
                "nestedObjInArrayKey": "Blah"
            ]
        ],
        "objKey": [
            "nestedStringKey": "Hello World!"
        ]
    ]
  
  func testCanonicalization() {
    XCTAssertNoThrow(try JSONUtils.canonicalize(jsonObj: obj1))
    let canonicalizedJson = try! JSONUtils.canonicalize(jsonObj: obj1)
    print(canonicalizedJson)
    var whitespaceCount = 0
    var scientificENotationCount = 0
    for c in canonicalizedJson {
        if c == " " {
            whitespaceCount += 1
        }
        if c == "E" {
            scientificENotationCount += 1
        }
    }
    XCTAssert(whitespaceCount == 1)
    XCTAssert(scientificENotationCount == 4)
    XCTAssertNoThrow(try JSONSerialization.jsonObject(with: canonicalizedJson.data(using: .utf8)!, options: JSONSerialization.ReadingOptions()), "Error parsing JSON")
  }
}
