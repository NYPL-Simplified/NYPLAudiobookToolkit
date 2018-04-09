//
//  HighlightedUIControl.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 4/9/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class HighlightedUIControl: UIControl {
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.25) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }
}
