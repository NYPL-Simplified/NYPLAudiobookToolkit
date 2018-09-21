//
//  HumanReadableTime.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/26/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

/// Utility class to turn a time interval
/// into a human readable string. The format will be
/// HH:MM:SS if the TimeInterval is longer than 1 hour,
/// otherwise it will be MM:SS.
class TimeIntervalStringHelper {
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

    lazy var description: String = {
        let interval = Int(self.timeInterval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        let formatStringWithoutHours = NSLocalizedString("%02dmin", bundle: Bundle.audiobookToolkit()!, value: "%02dmin", comment: "The numebr of minutes")
        var timeString = String(format: formatStringWithoutHours, minutes)
        if hours > 0 {
            let formatStringWithHours = NSLocalizedString("%02d hr %02 dmin", bundle: Bundle.audiobookToolkit()!, value: "%02d hr %02d min", comment: "Minutes, seconds and hours")
            timeString = String(format: formatStringWithHours, hours, minutes)
        }
        return timeString
    }()

    private let timeInterval: TimeInterval
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
}
