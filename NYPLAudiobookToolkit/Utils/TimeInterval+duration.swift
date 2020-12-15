//
//  TimeInterval+duration.swift
//  NYPLAudiobookToolkit
//
//  Created by Vladimir Fedorov on 07.12.2020.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import Foundation

extension TimeInterval {
    /// Converts ISO8601 duration string to `TimeInterval`
    /// - Parameter ISO8601Duration: ISO 8601 duration string (see [ISO 8601 duration specification](https://en.wikipedia.org/wiki/ISO_8601#Durations)).
    /// - Returns: `TimeInterval` for ISO 8601 string.
    static func from(ISO8601Duration: String) -> TimeInterval? {
        let formatter = ISO8601DurationFormatter()
        guard let components = formatter.dateComponents(from: ISO8601Duration),
            let date = Calendar.current.date(byAdding: components, to: Date(timeIntervalSinceReferenceDate: 0))
            else {
                return nil
        }
        return date.timeIntervalSinceReferenceDate
    }
}
