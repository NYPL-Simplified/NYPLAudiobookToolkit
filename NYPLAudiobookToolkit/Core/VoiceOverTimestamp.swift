//
//  VoiceOverTimestamp.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 3/30/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class VoiceOverTimestamp: NSObject {
    lazy var value: String = {
        let interval = Int(self.timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        if hours > 0 {
            return self.stringsForHours(hours: hours, minutes: minutes)
        } else if minutes > 0 {
            return self.stringForMinutes(minutes: minutes)
        } else {
            return self.stringForSeconds(seconds: seconds)
        }
    }()

    func stringForMinutes(minutes: Int) -> String {
        let format: String
        if minutes != 1 {
            format = NSLocalizedString("%d minutes", bundle: Bundle.audiobookToolkit()!, value: "%d minutes", comment: "Plural minutes with formatting")
        } else {
            format = NSLocalizedString("%d minute", bundle: Bundle.audiobookToolkit()!, value: "%d minute", comment: "Singular minutes")
        }
        return String(format: format, minutes)
    }
    
    func stringForSeconds(seconds: Int) -> String {
        let format: String
        if seconds != 1 {
            format = NSLocalizedString("%d seconds", bundle: Bundle.audiobookToolkit()!, value: "%d seconds", comment: "Plural seconds with formatting")
        } else {
            format = NSLocalizedString("%d second", bundle: Bundle.audiobookToolkit()!, value: "%d second", comment: "Singular minutes")
        }
        return String(format: format, seconds)
    }

    func stringsForHours(hours: Int, minutes: Int) -> String {
        let format: String
        if minutes != 1 && hours != 1 {
            format = NSLocalizedString("%d hours and %d minutes", bundle: Bundle.audiobookToolkit()!, value: "%d hours and %d minutes", comment: "Plural hours and minutes with formatting")
        } else if minutes != 1 && hours == 1 {
            format = NSLocalizedString("%d hour and %d minutes", bundle: Bundle.audiobookToolkit()!, value: "%d hour and %d minutes", comment: "Singular hours and plural minutes with formatting")
        } else if minutes == 1 && hours != 1 {
            format = NSLocalizedString("%d hours and %d minute", bundle: Bundle.audiobookToolkit()!, value: "%d hours and %d minute", comment: "Plural hours and singular minutes with formatting")
        } else {
            format = NSLocalizedString("%d hour and %d minute", bundle: Bundle.audiobookToolkit()!, value: "%d hour and %d minute", comment: "Singular hours and minutes with formatting")
        }
        return String(format: format, hours, minutes)
    }

    private let timeInterval: TimeInterval
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
}
