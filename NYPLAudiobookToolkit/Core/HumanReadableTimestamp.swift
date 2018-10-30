//
//  HumanReadableTime.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/26/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

/// Utility class to turn a time interval into a human readable string or timecode.
class HumanReadableTimestamp {
    lazy var timecode: String = {
        let interval = Int(self.timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        let formatStringWithoutHours = NSLocalizedString("%02d:%02d", bundle: Bundle.audiobookToolkit()!, value: "%02d:%02d", comment: "Minutes and seconds")
        var timeString = String(format: formatStringWithoutHours, minutes, seconds)
        if hours > 0 {
            let formatStringWithHours = NSLocalizedString("%02d:%02d:%02d", bundle: Bundle.audiobookToolkit()!, value: "%02d:%02d:%02d", comment: "Minutes, seconds and hours")
            timeString = String(format: formatStringWithHours, hours, minutes, seconds)
        }
        return timeString
    }()

    lazy var stringDescription: String = {
        let interval = Int(self.timeInterval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        let formatStringWithoutHours = NSLocalizedString("%02dmin", bundle: Bundle.audiobookToolkit()!, value: "%02dmin", comment: "The number of minutes")
        var timeString = String(format: formatStringWithoutHours, minutes)
        if hours > 0 {
            let formatStringWithHours = NSLocalizedString("%02d hr %02 dmin", bundle: Bundle.audiobookToolkit()!, value: "%02d hr %02d min", comment: "The number of hours and minutes")
            timeString = String(format: formatStringWithHours, hours, minutes)
        }
        return timeString
    }()

    lazy var accessibleDescription: String = {
        let interval = Int(self.timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        let formatStringWithoutHours = NSLocalizedString("%02d minutes and %02d seconds", bundle: Bundle.audiobookToolkit()!, value: "%02d minutes and %02d seconds", comment: "The number of minutes and seconds")
        var timeString = String(format: formatStringWithoutHours, minutes, seconds)
        if hours > 0 {
            let formatStringWithHours = NSLocalizedString("%02d hours, %02d minutes and %02d seconds", bundle: Bundle.audiobookToolkit()!, value: "%02d hours, %02d minutes and %02d seconds", comment: "The number of hours minutes and seconds")
            timeString = String(format: formatStringWithHours, hours, minutes, seconds)
        }
        return timeString
    }()

    private let timeInterval: TimeInterval
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
}
