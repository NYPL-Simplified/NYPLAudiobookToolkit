//
//  TextWithImageView.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/19/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

class TextOverImageView: UIView {
    
    var text: String? {
        get {
            return self.textLabel.text
        }
        set(newText) {
            self.textLabel.text = newText
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    init() {
        super.init(frame: .zero)
        self.setup()
    }
    
    func setup() {
        self.addSubview(self.backgroundImageView)
        self.backgroundImageView.autoPinEdgesToSuperviewEdges()
        self.addSubview(self.textLabel)
        self.textLabel.autoCenterInSuperview()
        self.textLabel.textAlignment = .center
        self.textLabel.numberOfLines = 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
