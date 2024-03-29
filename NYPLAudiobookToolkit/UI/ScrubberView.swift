//
//  Scrubber.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/18/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

protocol ScrubberViewDelegate: AnyObject {
    func scrubberView(_ scrubberView: ScrubberView, didRequestScrubTo offset: TimeInterval)
    func scrubberViewDidRequestAccessibilityIncrement(_ scrubberView: ScrubberView)
    func scrubberViewDidRequestAccessibilityDecrement(_ scrubberView: ScrubberView)
}

private func defaultTimeLabelWidth() -> CGFloat {
    return 60
}

struct ScrubberProgress {
    let offset: TimeInterval
    let duration: TimeInterval
    let timeLeftInBook: TimeInterval

    var timeLeftText: String {
        return HumanReadableTimestamp(timeInterval: self.timeLeft).timecode
    }

    var playheadText: String {
        return HumanReadableTimestamp(timeInterval: self.offset).timecode
    }

    var timeLeftInBookText: String {
        let timeLeft = HumanReadableTimestamp(timeInterval: self.timeLeftInBook).stringDescription
        let formatString = NSLocalizedString("%@ remaining", bundle: Bundle.audiobookToolkit()!, value: "%@ remaining", comment: "The amount of hours and minutes left")
        return String(format: formatString, timeLeft)
    }

    var labelWidth: CGFloat {
        if self.duration >= 3600 {
            return 82
        } else {
            return defaultTimeLabelWidth()
        }
    }

    var timeLeft: TimeInterval {
        return max(self.duration - self.offset, 0)
    }
    
    func progressFromPercentage(_ percentage: Float) -> ScrubberProgress {
        let newOffset = TimeInterval(Float(self.duration) * percentage)
        let difference = self.offset - newOffset
        return ScrubberProgress(
            offset: newOffset,
            duration: self.duration,
            timeLeftInBook: self.timeLeftInBook + difference
        )
    }
}

struct ScrubberUIState {
    let gripperHeight: CGFloat
    var progressColor: UIColor
    let progress: ScrubberProgress
    let middleText: String?
    let scrubbing: Bool
    var gripperWidth: CGFloat {
        return gripperHeight / 4
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
}

final class ScrubberView: UIView {
    weak var delegate: ScrubberViewDelegate?
    var trimColor: UIColor {
        if #available(iOS 12.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            return NYPLColor.actionColor
        } else {
            return UIColor.red
        }
    }
    let barHeight = 16
    let padding: CGFloat = 8
    var progressBar = UIView()
    let progressBackground = UIView()
    let gripper = UIView()
    let leftLabel = UILabel()
    let rightLabel = UILabel()
    let topLabel = { () -> UIScrubberLabel in
        let label = UIScrubberLabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        return label
    }()
    let middleLabel = UIScrubberLabel()
    
    var scrubbing: Bool {
        return self.state.scrubbing
    }

    var barWidthConstraint: NSLayoutConstraint?
    var progressBarWidth: CGFloat {
        return self.progressBackground.bounds.size.width
    }

    var labelWidthConstraints: [NSLayoutConstraint] = []
    var state: ScrubberUIState = ScrubberUIState(
        gripperHeight: 36,
        progressColor: UIColor.black,
        progress: ScrubberProgress(offset: 0, duration: 0, timeLeftInBook: 0),
        middleText: "",
        scrubbing: false
    ) {
        didSet {
            self.updateUIWith(self.state)
        }
    }
    
    public func setOffset(_ offset: TimeInterval, duration: TimeInterval, timeLeftInBook: TimeInterval, middleText: String?) {
        self.state = ScrubberUIState(
            gripperHeight: self.state.gripperHeight,
            progressColor: self.state.progressColor,
            progress: ScrubberProgress(offset: offset, duration: duration, timeLeftInBook: timeLeftInBook),
            middleText: middleText,
            scrubbing: self.state.scrubbing
        )
    }

    public func updateUIWith(_ state: ScrubberUIState) {
        self.leftLabel.text = self.state.progress.playheadText
        self.rightLabel.text = self.state.progress.timeLeftText
        self.topLabel.text = self.state.progress.timeLeftInBookText
        self.topLabel.accessibilityLabel = topLabelVoiceOverDescription()
        self.progressBackground.accessibilityLabel = progressBackgroundVoiceOverDescription()
        self.middleLabel.text = self.state.middleText
        self.setNeedsUpdateConstraints()
        self.layoutIfNeeded()
    }

    init() {
        super.init(frame: CGRect.zero)
        self.setupView()
        self.setupAccessibility()
        updateColors()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 12.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            updateColors()
        }
    }
    
    private func setupView () {
        self.accessibilityIdentifier = "scrubber_container"
        self.addSubview(self.topLabel)
        self.addSubview(self.progressBackground)
        self.addSubview(self.progressBar)
        self.addSubview(self.gripper)
        self.addSubview(self.leftLabel)
        self.addSubview(self.rightLabel)
        self.addSubview(self.middleLabel)
        
        self.progressBackground.autoSetDimension(.height, toSize: CGFloat(self.barHeight))
        self.progressBackground.autoPinEdge(.left, to: .left, of: self)
        self.progressBackground.autoPinEdge(.right, to: .right, of: self)
        self.progressBackground.accessibilityIdentifier = "progress_background"
        self.progressBackground.setContentCompressionResistancePriority(UILayoutPriority.required, for: NSLayoutConstraint.Axis.horizontal)
        self.progressBackground.setContentHuggingPriority(.defaultLow, for: NSLayoutConstraint.Axis.horizontal)

        self.leftLabel.autoPinEdge(.left, to: .left, of: self)
        self.leftLabel.autoAlignAxis(.horizontal, toSameAxisOf: self.middleLabel)
        let leftLabelWidth = self.leftLabel.autoSetDimension(.width, toSize: defaultTimeLabelWidth())
        self.leftLabel.numberOfLines = 1
        self.leftLabel.textAlignment = .left
        self.leftLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.horizontal)
        self.leftLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.vertical)
        self.leftLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: NSLayoutConstraint.Axis.horizontal)
        self.leftLabel.font = UIFont.systemFont(ofSize: 12)
        self.leftLabel.accessibilityIdentifier = "progress_leftLabel"
        self.leftLabel.text = self.state.progress.playheadText
        
        self.rightLabel.autoPinEdge(.right, to: .right, of: self)
        self.rightLabel.autoAlignAxis(.horizontal, toSameAxisOf: self.middleLabel)
        let rightLabelWidth = self.rightLabel.autoSetDimension(.width, toSize: defaultTimeLabelWidth())
        self.rightLabel.numberOfLines = 1
        self.rightLabel.textAlignment = .right
        self.rightLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.horizontal)
        self.rightLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.vertical)
        self.rightLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: NSLayoutConstraint.Axis.horizontal)
        self.rightLabel.font = UIFont.systemFont(ofSize: 12)
        self.rightLabel.accessibilityIdentifier = "progress_rightLabel"
        self.rightLabel.text = self.state.progress.timeLeftText
        
        self.middleLabel.autoPinEdge(.left, to: .right, of: self.leftLabel)
        self.middleLabel.autoPinEdge(.right, to: .left, of: self.rightLabel)
        self.middleLabel.autoPinEdge(.top, to: .bottom, of: self.gripper, withOffset: self.padding / 2)
        self.middleLabel.autoPinEdge(.bottom, to: .bottom, of: self)
        self.middleLabel.numberOfLines = 1
        self.middleLabel.textAlignment = .center
        self.middleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: NSLayoutConstraint.Axis.horizontal)
        self.middleLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.vertical)
        self.middleLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.horizontal)
        self.middleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        self.middleLabel.accessibilityIdentifier = "progress_rightLabel"

        self.labelWidthConstraints.append(leftLabelWidth)
        self.labelWidthConstraints.append(rightLabelWidth)

        self.progressBar.autoPinEdge(.left, to: .left, of: self.progressBackground)
        self.progressBar.autoSetDimension(.height, toSize: CGFloat(self.barHeight))
        self.barWidthConstraint = self.progressBar.autoSetDimension(.width, toSize: CGFloat(self.state.gripperHeight))
        self.progressBar.accessibilityIdentifier = "progress_bar"

        self.topLabel.autoPinEdge(.top, to: .top, of: self)
        self.topLabel.autoPinEdge(.left, to: .left, of: self)
        self.topLabel.autoPinEdge(.right, to: .right, of: self)
        self.topLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: NSLayoutConstraint.Axis.horizontal)
        self.topLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.vertical)
        self.topLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultHigh, for: NSLayoutConstraint.Axis.horizontal)
        
        self.gripper.autoPinEdge(.top, to: .bottom, of: self.topLabel, withOffset: self.padding / 2)
        self.gripper.autoAlignAxis(.horizontal, toSameAxisOf: self.progressBackground)
        self.gripper.autoAlignAxis(.horizontal, toSameAxisOf: self.progressBar)
        self.gripper.autoPinEdge(.right, to: .right, of: self.progressBar)
        self.gripper.layer.cornerRadius = 5
        self.gripper.autoSetDimensions(
            to: CGSize(
                width: self.state.gripperWidth,
                height: self.state.gripperHeight
            )
        )
        self.gripper.accessibilityIdentifier = "progress_grip"
    }
    
    private func setupAccessibility() {
        self.leftLabel.isAccessibilityElement = false
        self.rightLabel.isAccessibilityElement = false
        self.progressBackground.isAccessibilityElement = true
        self.progressBackground.accessibilityTraits = UIAccessibilityTraits(
            rawValue: super.accessibilityTraits.rawValue | UIAccessibilityTraits.updatesFrequently.rawValue
        )
        self.gripper.isAccessibilityElement = false
        self.progressBar.isAccessibilityElement = false
    }

    override func updateConstraints() {
        self.barWidthConstraint?.constant = self.state.progressLocationFor(self.progressBarWidth)
        self.labelWidthConstraints.forEach { (constraint) in
            constraint.constant = self.state.progress.labelWidth
        }
        super.updateConstraints()
    }
    
    private func updateColors() {
        if #available(iOS 12.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            self.progressBackground.backgroundColor = NYPLColor.progressBarBackgroundColor
            self.state.progressColor = NYPLColor.actionColor
        } else {
            self.progressBackground.backgroundColor = UIColor.darkGray
            self.state.progressColor = .black
        }
        
        self.progressBar.backgroundColor = self.state.progressColor
        self.gripper.backgroundColor = self.trimColor
        self.setNeedsDisplay()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func scrub(touch: UITouch?, currentlyScrubbing: Bool) {
        if let touch = touch {
            let position = touch.location(in: self.progressBackground)
            let percentage: Float
            if position.x >= 0 && position.x <= self.progressBarWidth {
                percentage = Float(position.x / self.progressBarWidth)
            } else if position.x < 0 {
                percentage = 0
            } else if position.x > self.progressBarWidth {
                percentage = 1.0
            } else {
                ATLog(.error, "Unknown scrub state")
                return
            }
            self.state = ScrubberUIState(
                gripperHeight: self.state.gripperHeight,
                progressColor: self.state.progressColor,
                progress: self.state.progress.progressFromPercentage(percentage),
                middleText: self.state.middleText,
                scrubbing: currentlyScrubbing
            )
        } else {
            self.state = ScrubberUIState(
                gripperHeight: self.state.gripperHeight,
                progressColor: self.state.progressColor,
                progress: self.state.progress,
                middleText: self.state.middleText,
                scrubbing: currentlyScrubbing
            )
        }
    }

    private func topLabelVoiceOverDescription() -> String {
        let accessibleString = NSLocalizedString("%@ remaining in the book.",
                                                 bundle: Bundle.audiobookToolkit()!,
                                                 value: "%@ remaining in the book.",
                                                 comment: "How much time is left in the entire book, not just the chapter.")
        let timestamp = VoiceOverTimestamp(timeInterval: self.state.progress.timeLeftInBook).value
        return String(format: accessibleString, timestamp)
    }

    private func progressBackgroundVoiceOverDescription() -> String {
        let offset = HumanReadableTimestamp(timeInterval: self.state.progress.offset).accessibleDescription
        let remaining = HumanReadableTimestamp(timeInterval: self.state.progress.timeLeft).accessibleDescription
        let accessibleString = NSLocalizedString("%@ played. %@ remaining.",
                                                 bundle: Bundle.audiobookToolkit()!,
                                                 value: "%@ played. %@ remaining.",
                                                 comment: "Time into the current chapter, then time remaining in the current chapter.")
        return String(format: accessibleString, offset, remaining)
    }

    //MARK:-

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.scrub(touch: touches.first, currentlyScrubbing: true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.scrub(touch: touches.first, currentlyScrubbing: true)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.scrub(touch: touches.first, currentlyScrubbing: false)
        self.delegate?.scrubberView(self, didRequestScrubTo: self.state.progress.offset)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.scrub(touch: touches.first, currentlyScrubbing: false)
        self.delegate?.scrubberView(self, didRequestScrubTo: self.state.progress.offset)
    }
}

final class UIScrubberLabel: UILabel {
    override func accessibilityActivate() -> Bool {
        return true
    }
}
