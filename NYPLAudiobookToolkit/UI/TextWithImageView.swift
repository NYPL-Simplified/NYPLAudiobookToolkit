//
//  TextWithImageView.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/19/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

class TextOverImageView: UIControl {
    
    var text: String? {
        get {
            return self.textLabel.text
        }
        set(newText) {
            self.textLabel.text = newText
        }
    }
    
    var subtext: String? {
        get {
            return self.subtextLabel.text
        }
        set(newText) {
            self.subtextLabel.text = newText
        }
    }

    var image: UIImage? {
        get {
            return self.backgroundImageView.image
        }
        set(newImage) {
            self.backgroundImageView.image = newImage
        }
    }
    
    private let backgroundImageView = UIImageView()
    private let textLabel = UILabel()
    private let subtextLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    init() {
        super.init(frame: .zero)
        self.setup()
    }
    
    func setup() {
        self.accessibilityTraits = UIAccessibilityTraitButton
        self.isAccessibilityElement = true

        self.addSubview(self.backgroundImageView)
        self.backgroundImageView.accessibilityIdentifier = "TextOverImageView.backgroundImageView"
        self.backgroundImageView.contentMode = .scaleAspectFit
        self.backgroundImageView.autoPinEdgesToSuperviewEdges()
        self.addSubview(self.textLabel)
        self.textLabel.accessibilityIdentifier = "TextOverImageView.textLabel"
        self.textLabel.font = UIFont.systemFont(ofSize: 20)
        self.textLabel.textAlignment = .center
        self.textLabel.numberOfLines = 1
        self.textLabel.autoCenterInSuperview()
        self.textLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        self.addSubview(self.subtextLabel)
        self.subtextLabel.accessibilityIdentifier = "TextOverImageView.subtextLabel"
        self.subtextLabel.font = UIFont.systemFont(ofSize: 12)
        self.subtextLabel.textAlignment = .center
        self.subtextLabel.numberOfLines = 1
        self.subtextLabel.autoPinEdge(.top, to: .bottom, of: self.textLabel, withOffset: -6)
        self.subtextLabel.autoAlignAxis(.vertical, toSameAxisOf: self.textLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
