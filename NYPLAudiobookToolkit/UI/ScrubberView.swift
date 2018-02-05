//
//  Scrubber.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/18/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

protocol ScrubberViewDelegate: class {
func scrubberView(_ scrubberView: ScrubberView, didRequestScrubTo completionPercentage: Int)
func scrubberViewDidBeginScrubbing(_ scrubberView: ScrubberView)
}

struct ScrubberUIState: Equatable {
    let progressXPosition: Int
    let gripperRadius: Int
    let leftText: String
    let rightText: String
    let progressColor: UIColor
    let isScrubbing: Bool
    var gripperDiameter: Int {
        return gripperRadius * 2
    }
    
    static func ==(lhs: ScrubberUIState, rhs: ScrubberUIState) -> Bool {
        return lhs.progressXPosition == rhs.progressXPosition &&
            lhs.gripperRadius == rhs.gripperRadius &&
            lhs.leftText == rhs.leftText &&
            lhs.rightText == rhs.rightText &&
            lhs.progressColor == rhs.progressColor &&
            lhs.isScrubbing == rhs.isScrubbing
    }
}

class ScrubberView: UIView {
    var delegate: ScrubberViewDelegate?
    
    let barHeight = 4
    var progressBar = UIView()
    let progressBackground = UIView()
    let gripper = UIView()
    let leftLabel = UILabel()
    let rightLabel = UILabel()
    var barWidthConstraint: NSLayoutConstraint?
    var gripperSizeConstraints: [NSLayoutConstraint]?
    private var states: [ScrubberUIState] = []
    var state: ScrubberUIState = ScrubberUIState(
        progressXPosition: 0,
        gripperRadius: 4,
        leftText: "0:00",
        rightText: "5:00",
        progressColor: UIColor.gray,
        isScrubbing: false
        ) {
        didSet {
            if let currentState = self.states.first {
                if currentState != self.state {
                    self.states.append(self.state)
                    self.updateUIWith(self.state)
                }
            } else {
                self.states.append(self.state)
                self.updateUIWith(self.state)
            }
        }
    }

    var timer: Timer?

    public func play() {
        self.state = ScrubberUIState(
            progressXPosition: self.state.gripperRadius,
            gripperRadius: self.state.gripperRadius,
            leftText: self.state.leftText,
            rightText: self.state.rightText,
            progressColor: self.state.progressColor,
            isScrubbing: true
        )
    }

    public func pause() {
        self.state = ScrubberUIState(
            progressXPosition: self.state.gripperRadius,
            gripperRadius: self.state.gripperRadius,
            leftText: self.state.leftText,
            rightText: self.state.rightText,
            progressColor: self.state.progressColor,
            isScrubbing: false
        )
    }

    public func updateUIWith(_ state: ScrubberUIState) {
        self.setNeedsUpdateConstraints()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    init() {
        super.init(frame: CGRect.zero)
        self.setup()
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func setup () {
        self.accessibilityIdentifier = "scrubber_container"

        self.addSubview(self.progressBackground)
        self.progressBackground.layer.cornerRadius = CGFloat(self.barHeight / 2)
        self.progressBackground.backgroundColor = UIColor.lightGray
        self.progressBackground.autoPinEdge(.left, to: .left, of: self)
        self.progressBackground.autoPinEdge(.right, to: .right, of: self)
        self.progressBackground.autoSetDimension(.height, toSize: CGFloat(self.barHeight))
        self.progressBackground.accessibilityIdentifier = "progress_background"
        
        self.addSubview(self.progressBar)
        self.progressBar.backgroundColor = self.state.progressColor
        self.progressBar.layer.cornerRadius = CGFloat(self.barHeight / 2)
        self.progressBar.autoPinEdge(.left, to: .left, of: self.progressBackground)
        self.progressBar.autoSetDimension(.height, toSize: CGFloat(self.barHeight))
        self.barWidthConstraint = self.progressBar.autoSetDimension(.width, toSize: CGFloat(self.state.gripperRadius))
        self.progressBar.accessibilityIdentifier = "progress_bar"
        
        self.addSubview(self.gripper)
        self.gripper.backgroundColor = self.state.progressColor
        self.gripper.layer.cornerRadius = CGFloat(self.state.gripperRadius)
        self.gripper.autoPinEdge(.top, to: .top, of: self)
        self.gripper.autoAlignAxis(.horizontal, toSameAxisOf: self.progressBackground)
        self.gripper.autoAlignAxis(.horizontal, toSameAxisOf: self.progressBar)
        self.gripper.autoPinEdge(.right, to: .right, of: self.progressBar)
        self.gripperSizeConstraints = self.gripper.autoSetDimensions(
            to: CGSize(
                width: self.state.gripperDiameter,
                height: self.state.gripperDiameter
            )
        )
        self.gripper.accessibilityIdentifier = "progress_grip"
        
        self.addSubview(self.leftLabel)
        self.leftLabel.autoPinEdge(.left, to: .left, of: self)
        self.leftLabel.autoPinEdge(.top, to: .bottom, of: self.gripper)
        self.leftLabel.autoPinEdge(.bottom, to: .bottom, of: self)
        self.leftLabel.accessibilityIdentifier = "progress_leftLabel"
        self.leftLabel.text = self.state.leftText
        
        self.addSubview(self.rightLabel)
        self.rightLabel.autoPinEdge(.right, to: .right, of: self)
        self.rightLabel.autoPinEdge(.top, to: .bottom, of: self.gripper)
        self.rightLabel.autoPinEdge(.bottom, to: .bottom, of: self)
        self.rightLabel.accessibilityIdentifier = "progress_rightLabel"
        self.rightLabel.text = self.state.rightText
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        UIView.beginAnimations("layout", context: nil)
        self.barWidthConstraint?.constant = CGFloat(self.state.progressXPosition)
        self.gripper.layer.cornerRadius = CGFloat(self.state.gripperRadius)
        self.gripperSizeConstraints?.forEach{ (constraint) in
            constraint.constant = CGFloat(self.state.gripperDiameter)
        }

        self.leftLabel.text = self.state.leftText
        self.rightLabel.text = self.state.rightText
        self.progressBar.backgroundColor = self.state.progressColor
        self.gripper.backgroundColor = self.state.progressColor
        UIView.commitAnimations()
        
        if self.timer == nil && self.state.isScrubbing {
            self.timer = Timer.scheduledTimer(
                timeInterval: 1,
                target: self,
                selector: #selector(ScrubberView.updateProgress(_:)),
                userInfo: nil,
                repeats: true
            )
        } else if !self.state.isScrubbing {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    @objc func updateProgress(_ sender: Any) {
        var newWidth = self.state.gripperRadius
        if (self.barWidthConstraint?.constant ?? CGFloat(0)) <= (self.frame.size.width - CGFloat(self.state.gripperRadius)) {
            newWidth = self.state.progressXPosition + 3
        }
        self.state = ScrubberUIState(
            progressXPosition: newWidth,
            gripperRadius: 4,
            leftText: self.state.leftText,
            rightText: self.state.rightText,
            progressColor: UIColor.gray,
            isScrubbing: self.state.isScrubbing
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func scrub(touch: UITouch?) {
        if let touch = touch {
            let postion = touch.location(in: self)
            if postion.x > 0 && postion.x < self.bounds.size.width {
                self.state = ScrubberUIState(
                    progressXPosition: Int(postion.x),
                    gripperRadius: 9,
                    leftText: self.state.leftText,
                    rightText: self.state.rightText,
                    progressColor: self.tintColor,
                    isScrubbing: false
                )

            }
        }
    }
    
    func stopScrub(touch: UITouch?) {
        if let touch = touch {
            let postion = touch.location(in: self)
            self.state = ScrubberUIState(
                progressXPosition: Int(postion.x),
                gripperRadius: 4,
                leftText: self.state.leftText,
                rightText: self.state.rightText,
                progressColor: UIColor.gray,
                isScrubbing: true
            )
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.scrub(touch: touches.first)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.scrub(touch: touches.first)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.stopScrub(touch: touches.first)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.stopScrub(touch: touches.first)
    }
}

