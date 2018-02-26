//
//  HumanReadableTime.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/26/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class HumanReadableTimeInterval {
    lazy var value: String = {
        let interval = Int(self.timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        var timeString = String(format: "%02d:%02d", minutes, seconds)
        if hours > 0 {
            timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return timeString
    }()

    private let timeInterval: TimeInterval
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
}
