//
//  HumanReadablePlaybackRate.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 3/27/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class HumanReadablePlaybackRate {
    lazy var value: String = {
        var output: String! = nil
        switch rate {
        case .threeQuartersTime:
            output = "0.75x"
        case .normalTime:
            output = "1x"
        case .oneAndAQuarterTime:
            output = "1.25x"
        case .oneAndAHalfTime:
            output = "1.50x"
        case .doubleTime:
            output = "2x"
        }
        return output
    }()
    let rate: PlaybackRate
    init(rate: PlaybackRate) {
        self.rate = rate
    }
}
