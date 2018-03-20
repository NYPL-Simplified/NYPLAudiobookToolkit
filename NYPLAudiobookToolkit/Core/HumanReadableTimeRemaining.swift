//
//  HumanReadableTimeRemaining.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 3/15/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class HumanReadableTimeRemaining {
    lazy var value: String = {
        let interval = Int(self.timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        var timeString = "Less than 1 min remaining"
        if hours > 0 {
            timeString = String(format: "%02d hr, %02d min remaining", hours, minutes)
        } else if minutes > 0 {
            timeString = String(format: "%02d min remaining", minutes)
        }
        return timeString
    }()

    private let timeInterval: TimeInterval
    public init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
}
