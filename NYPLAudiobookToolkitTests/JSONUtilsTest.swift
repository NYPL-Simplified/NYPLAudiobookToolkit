import Foundation
import XCTest

@testable import NYPLAudiobookToolkit

fileprivate let complexString = String.init(data: Data(bytes: [34, 70, 111, 111, 9, 66, 97, 114, 92]), encoding: .utf8)!
fileprivate let complexStringExpected = #"\"Foo\u0009Bar\\"#
fileprivate let obj1: [String: Any?] = [
    "stringKey": complexString, // Should be \"Foo\u0009Bar\\
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

class JSONUtilsTest: XCTestCase {
  func testCanonicalization() {
    XCTAssertNoThrow(try JSONUtils.canonicalize(jsonObj: obj1))
    let canonicalizedJson = try! JSONUtils.canonicalize(jsonObj: obj1)
    print(canonicalizedJson)
    XCTAssert(canonicalizedJson.contains(complexStringExpected))
    var spaceCount = 0
    var scientificENotationCount = 0
    for c in canonicalizedJson {
        if c == " " {
            spaceCount += 1
        }
        if c == "E" {
            scientificENotationCount += 1
        }
    }
    XCTAssert(spaceCount == 1)
    XCTAssert(scientificENotationCount == 4)
    XCTAssertNoThrow(try JSONSerialization.jsonObject(with: canonicalizedJson.data(using: .utf8)!, options: JSONSerialization.ReadingOptions()), "Error parsing JSON")
  }
}
