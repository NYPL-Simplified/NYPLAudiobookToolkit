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
    func scrubberView(_ scrubberView: ScrubberView, didRequestScrubTo offset: TimeInterval)
}

private func defaultTimeLabelWidth() -> CGFloat {
    return 60
}

struct ScrubberProgress: Equatable {
    let offset: TimeInterval
    let duration: TimeInterval

    var timeLeftText: String {
        return HumanReadableTimeStamp(timeInterval: self.timeLeft, isDecreasing: true).value
    }

    var playheadText: String {
        return HumanReadableTimeStamp(timeInterval: self.offset).value
    }
    
    var labelWidth: CGFloat {
        if self.duration >= 3600 {
            return 82
        } else {
            return defaultTimeLabelWidth()
        }
    }

    var timeLeft: TimeInterval {
        return self.duration - self.offset
    }

    var succ: ScrubberProgress {
        let newOffset = self.offset <= self.duration ? self.offset + 1 : self.duration
        return ScrubberProgress(offset: newOffset, duration: self.duration)
    }
    
    func progressFromPrecentage(_ percentage: Float) -> ScrubberProgress {
        return ScrubberProgress(
            offset: TimeInterval(Float(self.duration) * percentage),
            duration: self.duration
        )
    }

    static func ==(lhs: ScrubberProgress, rhs: ScrubberProgress) -> Bool {
        return lhs.offset == rhs.offset &&
            lhs.duration == rhs.duration
    }
}

struct ScrubberUIState: Equatable {
    let gripperHeight: CGFloat
    let progressColor: UIColor
    let isScrubbing: Bool
    let progress: ScrubberProgress
    var gripperWidth: CGFloat {
        return gripperHeight / 3
    }

    public func progressLocationFor(_ width: CGFloat) -> CGFloat {
        var progressLocation = self.gripperHeight
        if self.progress.duration > 0 {
            progressLocation = CGFloat(self.progress.offset / self.progress.duration) * width
        }
        
        // Somehow our offset is greater than our duration, and our location is greater than the width of the actual playing content
        if progressLocation > width {
            progressLocation = width
        }

        return max(self.gripperWidth, progressLocation)
    }

    static func ==(lhs: ScrubberUIState, rhs: ScrubberUIState) -> Bool {
        return lhs.gripperHeight == rhs.gripperHeight &&
            lhs.progressColor == rhs.progressColor &&
            lhs.progress == rhs.progress &&
            lhs.isScrubbing == rhs.isScrubbing
    }
}

final class ScrubberView: UIView {
    var delegate: ScrubberViewDelegate?
    let trimColor: UIColor
    let barHeight = 16
    var progressBar = UIView()
    let progressBackground = UIView()
    let gripper = UIView()
    let leftLabel = UILabel()
    let rightLabel = UILabel()
    let middleLabel = UILabel()
    var barWidthConstraint: NSLayoutConstraint?

    var progressBarWidth: CGFloat {
        return self.progressBackground.bounds.size.width
    }

    var labelWidthConstraints: [NSLayoutConstraint] = []
    var state: ScrubberUIState = ScrubberUIState(
        gripperHeight: 26,
        progressColor: UIColor.black,
        isScrubbing: false,
        progress: ScrubberProgress(offset: 0, duration: 0)
    ) {
        didSet {
            self.updateUIWith(self.state)
        }
    }
    
    public func setOffset(_ offset: TimeInterval, duration: TimeInterval) {
        self.state = ScrubberUIState(
            gripperHeight: self.state.gripperHeight,
            progressColor: self.state.progressColor,
            isScrubbing: self.state.isScrubbing,
            progress: ScrubberProgress(offset: offset, duration: duration)
        )
    }
    
    public func setMiddle(text: String?) {
        self.middleLabel.text = text
    }

    var timer: Timer?

    public func play() {
        self.state = ScrubberUIState(
            gripperHeight: self.state.gripperHeight,
            progressColor: self.state.progressColor,
            isScrubbing: true,
            progress: self.state.progress
        )
    }

    public func pause() {
        self.state = ScrubberUIState(
            gripperHeight: self.state.gripperHeight,
            progressColor: self.state.progressColor,
            isScrubbing: false,
            progress: self.state.progress
        )
    }

    public func updateUIWith(_ state: ScrubberUIState) {
        self.leftLabel.text = self.state.progress.playheadText
        self.rightLabel.text = self.state.progress.timeLeftText
        self.setNeedsUpdateConstraints()
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

    init(tintColor: UIColor = UIColor.red) {
        self.trimColor = tintColor
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
        self.addSubview(self.leftLabel)
        self.addSubview(self.rightLabel)
        self.addSubview(self.middleLabel)
        self.progressBackground.backgroundColor = UIColor.darkGray
        self.progressBackground.autoSetDimension(.height, toSize: CGFloat(self.barHeight))
        self.progressBackground.autoPinEdge(.left, to: .left, of: self)
        self.progressBackground.autoPinEdge(.right, to: .right, of: self)
        self.progressBackground.accessibilityIdentifier = "progress_background"
        self.progressBackground.setContentCompressionResistancePriority(UILayoutPriority.required, for: UILayoutConstraintAxis.horizontal)
        self.progressBackground.setContentHuggingPriority(.defaultLow, for: UILayoutConstraintAxis.horizontal)

        self.leftLabel.autoPinEdge(.left, to: .left, of: self)
        self.leftLabel.autoPinEdge(.top, to: .bottom, of: self.progressBackground, withOffset: 6)
        self.leftLabel.autoPinEdge(.bottom, to: .bottom, of: self, withOffset: 0, relation: .greaterThanOrEqual)
        let leftLabelWidth = self.leftLabel.autoSetDimension(.width, toSize: defaultTimeLabelWidth())
        self.leftLabel.numberOfLines = 1
        self.leftLabel.textAlignment = .left
        self.leftLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: UILayoutConstraintAxis.horizontal)
        self.leftLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: UILayoutConstraintAxis.horizontal)
        self.leftLabel.font = UIFont.systemFont(ofSize: 12)
        self.leftLabel.accessibilityIdentifier = "progress_leftLabel"
        self.leftLabel.text = self.state.progress.playheadText
        
        self.rightLabel.autoPinEdge(.right, to: .right, of: self)
        self.rightLabel.autoPinEdge(.top, to: .bottom, of: self.progressBackground, withOffset: 6)
        self.rightLabel.autoPinEdge(.bottom, to: .bottom, of: self)
        self.rightLabel.autoPinEdge(.bottom, to: .bottom, of: self, withOffset: 0, relation: .greaterThanOrEqual)
        let rightLabelWidth = self.rightLabel.autoSetDimension(.width, toSize: defaultTimeLabelWidth())
        self.rightLabel.numberOfLines = 1
        self.rightLabel.textAlignment = .right
        self.rightLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: UILayoutConstraintAxis.horizontal)
        self.rightLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: UILayoutConstraintAxis.horizontal)
        self.rightLabel.font = UIFont.systemFont(ofSize: 12)
        self.rightLabel.accessibilityIdentifier = "progress_rightLabel"
        self.rightLabel.text = self.state.progress.timeLeftText
        
        self.middleLabel.autoPinEdge(.left, to: .right, of: self.leftLabel)
        self.middleLabel.autoPinEdge(.right, to: .left, of: self.rightLabel)
        self.middleLabel.autoPinEdge(.top, to: .bottom, of: self.progressBackground, withOffset: 6)
        self.middleLabel.autoPinEdge(.bottom, to: .bottom, of: self)
        self.middleLabel.numberOfLines = 1
        self.middleLabel.textAlignment = .center
        self.middleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: UILayoutConstraintAxis.horizontal)
        self.middleLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultHigh, for: UILayoutConstraintAxis.horizontal)
        self.middleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        self.middleLabel.accessibilityIdentifier = "progress_rightLabel"

        self.labelWidthConstraints.append(leftLabelWidth)
        self.labelWidthConstraints.append(rightLabelWidth)

        self.addSubview(self.progressBar)
        self.progressBar.backgroundColor = self.state.progressColor
        self.progressBar.autoPinEdge(.left, to: .left, of: self.progressBackground)
        self.progressBar.autoSetDimension(.height, toSize: CGFloat(self.barHeight))
        self.barWidthConstraint = self.progressBar.autoSetDimension(.width, toSize: CGFloat(self.state.gripperHeight))
        self.progressBar.accessibilityIdentifier = "progress_bar"
        
        self.addSubview(self.gripper)
        self.gripper.backgroundColor = self.state.progressColor
        self.gripper.autoPinEdge(.top, to: .top, of: self)
        self.gripper.autoAlignAxis(.horizontal, toSameAxisOf: self.progressBackground)
        self.gripper.autoAlignAxis(.horizontal, toSameAxisOf: self.progressBar)
        self.gripper.autoPinEdge(.right, to: .right, of: self.progressBar)
        self.gripper.autoSetDimensions(
            to: CGSize(
                width: self.state.gripperWidth,
                height: self.state.gripperHeight
            )
        )
        self.gripper.accessibilityIdentifier = "progress_grip"
        
        self.labelWidthConstraints.append(leftLabelWidth)
        self.labelWidthConstraints.append(rightLabelWidth)
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        UIView.beginAnimations("layout", context: nil)
        self.barWidthConstraint?.constant = self.state.progressLocationFor(self.progressBarWidth)
        self.progressBar.backgroundColor = self.state.progressColor
        self.gripper.backgroundColor = self.trimColor
        self.labelWidthConstraints.forEach { (constraint) in
            constraint.constant = self.state.progress.labelWidth
        }
        UIView.commitAnimations()
    }
    
    @objc func updateProgress(_ timer: Timer) {
        if self.state.progress.duration == 0 {
            timer.invalidate()
            return
        }

        guard self.state.isScrubbing else {
            return
        }
    
        self.state = ScrubberUIState(
            gripperHeight: self.state.gripperHeight,
            progressColor: self.state.progressColor,
            isScrubbing: self.state.isScrubbing,
            progress: self.state.progress.succ
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func scrub(touch: UITouch?) {
        if let touch = touch {
            let position = touch.location(in: self.progressBackground)
            if position.x > 0 && position.x < self.progressBarWidth {
                let percentage = Float(position.x / self.progressBarWidth)
                self.state = ScrubberUIState(
                    gripperHeight: self.state.gripperHeight,
                    progressColor: self.state.progressColor,
                    isScrubbing: false,
                    progress: self.state.progress.progressFromPrecentage(percentage)
                )
            }
        }
    }
    
    func stopScrub(touch: UITouch?) {
        if let touch = touch {
            let position = touch.location(in: self.progressBackground)
            if position.x > 0 && position.x < self.progressBarWidth {
                let percentage = Float(position.x / self.progressBarWidth)
                self.state = ScrubberUIState(
                    gripperHeight: self.state.gripperHeight,
                    progressColor: self.state.progressColor,
                    isScrubbing: true,
                    progress: self.state.progress.progressFromPrecentage(percentage)
                )
            }
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
        self.delegate?.scrubberView(self, didRequestScrubTo: self.state.progress.offset)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.stopScrub(touch: touches.first)
        self.delegate?.scrubberView(self, didRequestScrubTo: self.state.progress.offset)
    }
}

