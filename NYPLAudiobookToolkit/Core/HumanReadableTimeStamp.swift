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
class HumanReadableTimeStamp {
    lazy var value: String = {
        let interval = Int(self.timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        var timeString = String(format: "%02d:%02d", minutes, seconds)
        if hours > 0 {
            timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        if self.isDecreasing {
            timeString = "-\(timeString)"
        }
        return timeString
    }()

    private let timeInterval: TimeInterval
    private let isDecreasing: Bool
    init(timeInterval: TimeInterval, isDecreasing: Bool = false) {
        self.timeInterval = timeInterval
        self.isDecreasing = isDecreasing
    }
}
