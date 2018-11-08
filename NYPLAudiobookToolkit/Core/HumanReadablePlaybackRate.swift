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
            output = NSLocalizedString("0.75×", bundle: Bundle.audiobookToolkit()!, value: "0.75×", comment: "Three quaters time")
        case .normalTime:
            output = NSLocalizedString("1.0× (Normal)", bundle: Bundle.audiobookToolkit()!, value: "1.0× (Normal)", comment: "Normal time")
        case .oneAndAQuarterTime:
            output = NSLocalizedString("1.25×", bundle: Bundle.audiobookToolkit()!, value: "1.25×", comment: "One and a quarter time")
        case .oneAndAHalfTime:
            output = NSLocalizedString("1.50×", bundle: Bundle.audiobookToolkit()!, value: "1.50×", comment: "One and a half time")
        case .doubleTime:
            output = NSLocalizedString("2.0×", bundle: Bundle.audiobookToolkit()!, value: "2.0×", comment: "Double time")
        }
        return output
    }()
    lazy var accessibleDescription: String = {
        let output: String
        switch rate {
        case .threeQuartersTime:
            output = NSLocalizedString("Three quarters of normal speed. Slower.", bundle: Bundle.audiobookToolkit()!, value: "Three quarters of normal speed. Slower.", comment: "")
        case .normalTime:
            output = NSLocalizedString("Normal speed.", bundle: Bundle.audiobookToolkit()!, value: "Normal speed.", comment: "")
        case .oneAndAQuarterTime:
            output = NSLocalizedString("One and one quarter faster than normal speed.", bundle: Bundle.audiobookToolkit()!, value: "One and one quarter faster than normal speed.", comment: "")
        case .oneAndAHalfTime:
            output = NSLocalizedString("One and a half times faster than normal speed.", bundle: Bundle.audiobookToolkit()!, value: "One and a half times faster than normal speed.", comment: "")
        case .doubleTime:
            output = NSLocalizedString("Two times normal speed. Fastest.", bundle: Bundle.audiobookToolkit()!, value: "Two times normal speed. Fastest.", comment: "")
        }
        return output
    }()
    let rate: PlaybackRate
    init(rate: PlaybackRate) {
        self.rate = rate
    }
}
