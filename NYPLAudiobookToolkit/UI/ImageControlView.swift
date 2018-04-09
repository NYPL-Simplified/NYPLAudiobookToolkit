//
//  ImageControlView.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 4/9/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

class ImageControlView: HighlightedUIControl {

    var image: UIImage? {
        get {
            return self.imageView.image
        }
        set(newImage) {
            self.imageView.image = newImage
        }
    }
    private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.accessibilityIdentifier = "play_button"
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    init() {
        super.init(frame: .zero)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        self.accessibilityTraits = UIAccessibilityTraitButton
        self.isAccessibilityElement = true

        self.addSubview(self.imageView)
        self.imageView.autoPinEdgesToSuperviewEdges()
    }
}
