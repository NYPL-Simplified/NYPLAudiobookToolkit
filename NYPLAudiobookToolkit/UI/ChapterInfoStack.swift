//
//  ChapterInfoStack.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 3/16/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

class ChapterInfoStack: UIView {
    var titleText: String? {
        get {
            return self.topLabel.text
        }
        set(newText) {
            self.topLabel.text = newText
        }
    }
    
    var authors: [String] = [] {
        didSet {
            self.bottomLabel.text = self.authors.joined(separator: ", ")
            self.bottomLabel.accessibilityLabel = self.authors.joined(separator: " and ")
        }
    }

    
    private let topLabel = UILabel()
    private let bottomLabel = UILabel()
    private override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    init() {
        super.init(frame: CGRect.zero)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        self.addSubview(self.topLabel)
        self.addSubview(self.bottomLabel)

        self.topLabel.autoPinEdge(.top, to: .top, of: self)
        self.topLabel.autoPinEdge(.left, to: .left, of: self)
        self.topLabel.autoPinEdge(.right, to: .right, of: self)
        self.topLabel.textAlignment = .center
        self.topLabel.font = UIFont.boldSystemFont(ofSize: 16)
        self.topLabel.setContentHuggingPriority(.defaultLow, for: .vertical)

        self.bottomLabel.autoPinEdge(.top, to: .bottom, of: self.topLabel)
        self.bottomLabel.autoPinEdge(.left, to: .left, of: self)
        self.bottomLabel.autoPinEdge(.right, to: .right, of: self)
        self.bottomLabel.autoPinEdge(.bottom, to: .bottom, of: self)
        self.bottomLabel.textAlignment = .center
        self.bottomLabel.font = UIFont.systemFont(ofSize: 16)
        self.bottomLabel.textColor = UIColor.darkGray
        self.bottomLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    }
}

