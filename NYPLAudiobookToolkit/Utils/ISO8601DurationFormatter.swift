/*
 MIT License

 Copyright (c) 2019 kkla320

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import Foundation

/**
 A formatter that converts between durations specified by [ISO 8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations) values
 */
public class ISO8601DurationFormatter: Formatter {
    private let dateUnitMapping: [Character: Calendar.Component] = ["Y": .year, "M": .month, "W": .weekOfYear, "D": .day]
    private let timeUnitMapping: [Character: Calendar.Component] = ["H": .hour, "M": .minute, "S": .second]
    
    /**
    Return a [DateComponents](https://developer.apple.com/documentation/foundation/datecomponents) object created by parsing a given [ISO 8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations) string
    ```
    let input = "PT40M30S"
    let dateComponents = formatter.dateComponents(from: input)
    if let dateComponents = dateComponents {
        print(dateComponents.minute) // 40
        print(dateComponents.seconds) // 30
    }
    ```
    - parameter string: A [String](https://developer.apple.com/documentation/swift/string) object that is parsed to generate the returned [DateComponents](https://developer.apple.com/documentation/foundation/datecomponents) object.
    - returns: A  [DateComponents](https://developer.apple.com/documentation/foundation/datecomponents) object created by parsing `string`, or `nil` if string could not be parsed
     */
    public func dateComponents(from string: String) -> DateComponents? {
        var dateComponents: AnyObject? = nil
        if getObjectValue(&dateComponents, for: string, errorDescription: nil) {
            return dateComponents as? DateComponents
        }
        
        return nil
    }
    
    public override func string(for obj: Any?) -> String? {
        return nil
    }
    
    public override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        guard let unitValues = durationUnitValues(for: string) else {
            return false
        }

        var components = DateComponents()
        for (unit, value) in unitValues {
            components.setValue(value, for: unit)
        }
        obj?.pointee = components as AnyObject
        return true
    }
    
    private func durationUnitValues(for string: String) -> [(Calendar.Component, Int)]? {
        guard string.hasPrefix("P") else {
            return nil
        }

        let duration = String(string.dropFirst())

        guard let separatorRange = duration.range(of: "T") else {
            return unitValuesWithMapping(for: duration, dateUnitMapping)
        }

        let date = String(duration[..<separatorRange.lowerBound])
        let time = String(duration[separatorRange.upperBound...])

        guard let dateUnits = unitValuesWithMapping(for: date, dateUnitMapping),
              let timeUnits = unitValuesWithMapping(for: time, timeUnitMapping) else {
            return nil
        }

        return dateUnits + timeUnits
    }
    
    func unitValuesWithMapping(for string: String, _ mapping: [Character: Calendar.Component]) -> [(Calendar.Component, Int)]? {
        if string.isEmpty {
            return []
        }

        var components: [(Calendar.Component, Int)] = []

        let identifiersSet = CharacterSet(charactersIn: String(mapping.keys))

        let scanner = Scanner(string: string)
        while !scanner.isAtEnd {
            var value: Int = 0
            guard scanner.scanInt(&value) else {
                return nil
            }

            var scannedIdentifier: NSString?
            guard scanner.scanCharacters(from: identifiersSet, into: &scannedIdentifier) else {
                return nil
            }

            guard let identifier = scannedIdentifier as String? else {
                return nil
            }

            let unit = mapping[Character(identifier)]!
            components.append((unit, value))
        }
        return components
    }
}
