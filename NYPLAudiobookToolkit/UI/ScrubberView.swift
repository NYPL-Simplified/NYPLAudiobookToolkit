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
    func scrubberViewDidBeginScrubbing(_ scrubberView: ScrubberView)
}

struct ScrubberProgress: Equatable {
    let offset: TimeInterval
    let duration: TimeInterval
    
    var durationText: String {
        return self.timeIntervalToString(self.duration)
    }
    
    var offsetText: String {
        return self.timeIntervalToString(self.offset)
    }
    
    var succ: ScrubberProgress {
        let newOffset = self.offset < self.duration ? self.offset + 1 : self.duration
        return ScrubberProgress(offset: newOffset, duration: self.duration)
    }
    
    func progressFromPrecentage(_ percentage: Float) -> ScrubberProgress {
        return ScrubberProgress(
            offset: TimeInterval(Float(self.duration) * percentage),
            duration: self.duration
        )
    }

    func timeIntervalToString(_ interval: TimeInterval) -> String {
        let interval = Int(interval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        var timeString = String(format: "%02d:%02d", minutes, seconds)
        if hours > 0 {
            timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return timeString
    }

    static func ==(lhs: ScrubberProgress, rhs: ScrubberProgress) -> Bool {
        return lhs.offset == rhs.offset &&
            lhs.duration == rhs.duration
    }
}

struct ScrubberUIState: Equatable {
    let gripperRadius: CGFloat
    let progressColor: UIColor
    let isScrubbing: Bool
    let progress: ScrubberProgress
    var gripperDiameter: CGFloat {
        return gripperRadius * 2
    }

    public func progressLocationFor(_ width: CGFloat) -> CGFloat {
        var progressLocation = self.gripperRadius
        if self.progress.duration > 0 {
            progressLocation = CGFloat(self.progress.offset / self.progress.duration) * (width - CGFloat(self.gripperRadius))
        }
        
        // Somehow out offset is greater than our duration, and our location is greater than the width of the actual playing content
        if progressLocation > width {
            progressLocation = width

        }
        return progressLocation
    }

    static func ==(lhs: ScrubberUIState, rhs: ScrubberUIState) -> Bool {
        return lhs.gripperRadius == rhs.gripperRadius &&
            lhs.progressColor == rhs.progressColor &&
            lhs.progress == rhs.progress &&
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
    var state: ScrubberUIState = ScrubberUIState(
        gripperRadius: 4,
        progressColor: UIColor.gray,
        isScrubbing: false,
        progress: ScrubberProgress(offset: 0, duration: 0)
    ) {
        didSet {
            self.updateUIWith(self.state)
        }
    }
    
    public func setOffset(_ offset: TimeInterval, duration: TimeInterval) {
        self.state = ScrubberUIState(
            gripperRadius: self.state.gripperRadius,
            progressColor: self.state.progressColor,
            isScrubbing: self.state.isScrubbing,
            progress: ScrubberProgress(offset: offset, duration: duration)
        )
    }
    var timer: Timer?

    public func play() {
        self.state = ScrubberUIState(
            gripperRadius: self.state.gripperRadius,
            progressColor: self.state.progressColor,
            isScrubbing: true,
            progress: self.state.progress
        )
    }

    public func pause() {
        self.state = ScrubberUIState(
            gripperRadius: self.state.gripperRadius,
            progressColor: self.state.progressColor,
            isScrubbing: false,
            progress: self.state.progress
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
        self.leftLabel.text = self.state.progress.offsetText
        
        self.addSubview(self.rightLabel)
        self.rightLabel.autoPinEdge(.right, to: .right, of: self)
        self.rightLabel.autoPinEdge(.top, to: .bottom, of: self.gripper)
        self.rightLabel.autoPinEdge(.bottom, to: .bottom, of: self)
        self.rightLabel.accessibilityIdentifier = "progress_rightLabel"
        self.rightLabel.text = self.state.progress.durationText
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        UIView.beginAnimations("layout", context: nil)
        self.barWidthConstraint?.constant = self.state.progressLocationFor(self.frame.size.width)
        self.gripper.layer.cornerRadius = CGFloat(self.state.gripperRadius)
        self.gripperSizeConstraints?.forEach{ (constraint) in
            constraint.constant = CGFloat(self.state.gripperDiameter)
        }

        self.leftLabel.text = self.state.progress.offsetText
        self.rightLabel.text = self.state.progress.durationText
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
    
    @objc func updateProgress(_ timer: Timer) {
        if self.state.progress.duration == 0 {
            timer.invalidate()
            return
        }

        self.state = ScrubberUIState(
            gripperRadius: 4,
            progressColor: UIColor.gray,
            isScrubbing: self.state.isScrubbing,
            progress: self.state.progress.succ
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func scrub(touch: UITouch?) {
        if let touch = touch {
            let position = touch.location(in: self)
            if position.x > 0 && position.x < self.bounds.size.width {
                let percentage = Float(position.x / self.bounds.size.width)
                self.state = ScrubberUIState(
                    gripperRadius: 9,
                    progressColor: self.tintColor,
                    isScrubbing: false,
                    progress: self.state.progress.progressFromPrecentage(percentage)
                )

            }
        }
    }
    
    func stopScrub(touch: UITouch?) {
        if let touch = touch {
            let position = touch.location(in: self)
            if position.x > 0 && position.x < self.bounds.size.width {
                let percentage = Float(position.x / self.bounds.size.width)
                self.state = ScrubberUIState(
                    gripperRadius: 4,
                    progressColor: UIColor.gray,
                    isScrubbing: true,
                    progress: self.state.progress.progressFromPrecentage(percentage)
                )
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.scrub(touch: touches.first)
        self.delegate?.scrubberViewDidBeginScrubbing(self)
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

