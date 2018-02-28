//
//  HumanReadablePercentage.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/28/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class HumanReadablePercentage {
    lazy var value = { () -> String in
        return "\(Int(self.percentage * 100))"
    }()

    private let percentage: Float
    public init(percentage: Float) {
        self.percentage = percentage
    }
}
