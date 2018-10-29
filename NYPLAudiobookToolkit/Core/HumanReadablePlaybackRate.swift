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
    lazy var accessibleDescription: String = {
        let output: String
        switch rate {
        case .threeQuartersTime:
            output = NSLocalizedString("Slowest. Three quarters of normal speed.", bundle: Bundle.audiobookToolkit()!, value: "Slower. Three quarters of normal speed.", comment: "")
        case .normalTime:
            output = NSLocalizedString("Normal speed.", bundle: Bundle.audiobookToolkit()!, value: "Normal speed.", comment: "")
        case .oneAndAQuarterTime:
            output = NSLocalizedString("One and one quarter faster than normal speed.", bundle: Bundle.audiobookToolkit()!, value: "One and one quarter faster than normal speed.", comment: "")
        case .oneAndAHalfTime:
            output = NSLocalizedString("One and a half times faster than normal speed.", bundle: Bundle.audiobookToolkit()!, value: "One and a half times faster than normal speed.", comment: "")
        case .doubleTime:
            output = NSLocalizedString("Fastest. Two times normal speed.", bundle: Bundle.audiobookToolkit()!, value: "Fastest. Two times normal speed.", comment: "")
        }
        return output
    }()
    let rate: PlaybackRate
    init(rate: PlaybackRate) {
        self.rate = rate
    }
}
