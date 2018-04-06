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
        let output: String
        switch rate {
        case .threeQuartersTime:
            output = NSLocalizedString("0.75x", bundle: Bundle.audiobookToolkit()!, value: "0.75x", comment: "Three quaters time")
        case .normalTime:
            output = NSLocalizedString("1x", bundle: Bundle.audiobookToolkit()!, value: "1x", comment: "Normal time")
        case .oneAndAQuarterTime:
            output = NSLocalizedString("1.25x", bundle: Bundle.audiobookToolkit()!, value: "1.25x", comment: "One and a quarter time")
        case .oneAndAHalfTime:
            output = NSLocalizedString("1.50x", bundle: Bundle.audiobookToolkit()!, value: "1.50x", comment: "One and a half time")
        case .doubleTime:
            output = NSLocalizedString("2x", bundle: Bundle.audiobookToolkit()!, value: "2x", comment: "Double time")
        }
        return output
    }()
    let rate: PlaybackRate
    init(rate: PlaybackRate) {
        self.rate = rate
    }
}
