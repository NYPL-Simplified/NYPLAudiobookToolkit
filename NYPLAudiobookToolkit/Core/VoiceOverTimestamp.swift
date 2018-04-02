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
            return "\(hours) hours and \(minutes) minutes"
        } else if minutes > 0 {
            return "\(minutes) minutes"
        } else {
            return "\(seconds) seconds"
        }
    }()
    
    private let timeInterval: TimeInterval
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
}
