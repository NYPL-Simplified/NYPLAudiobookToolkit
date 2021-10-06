//
//  PlaybackControlView.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout
import AVKit
import MediaPlayer


protocol PlaybackControlViewDelegate: class {
    func playbackControlViewPlayButtonWasTapped(_ playbackControlView: PlaybackControlView)
    func playbackControlViewPauseButtonWasTapped(_ playbackControlView: PlaybackControlView)
    func playbackControlViewSkipForwardButtonWasTapped(_ playbackControlView: PlaybackControlView)
    func playbackControlViewSkipBackButtonWasTapped(_ playbackControlView: PlaybackControlView)
}

final class PlaybackControlView: UIView {
    weak var delegate: PlaybackControlViewDelegate?
    var skipForwardValue: Int = 15
    var skipBackValue: Int = 15

    public func showPlayButtonIfNeeded () {
        if self.playButton.image != self.playImage  {
            self.setToPlayIcon()
        }
    }
    
    public func showPauseButtonIfNeeded () {
        if self.playButton.image != self.pauseImage {
            self.setToPauseIcon()
        }
    }

    public func togglePlayPauseButtonUIState() {
        if self.playButton.image == self.playImage {
            self.setToPauseIcon()
        } else {
            self.setToPlayIcon()
        }
    }

    private func setToPauseIcon() {
        self.playButton.image = self.pauseImage
        self.playButton.accessibilityLabel = NSLocalizedString("Pause", bundle: Bundle.audiobookToolkit()!, value: "Pause", comment: "Pause")
    }

    private func setToPlayIcon() {
        self.playButton.image = self.playImage
        self.playButton.accessibilityLabel = NSLocalizedString("Play", bundle: Bundle.audiobookToolkit()!, value: "Play", comment: "Play")
    }

    private var horizontalPadding = CGFloat(30)
    private let skipBackView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_back", in: Bundle.audiobookToolkit(), compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        view.tintColor = NYPLColor.primaryTextColor
        view.subtext = NSLocalizedString("sec", bundle: Bundle.audiobookToolkit()!, value: "sec", comment: "Abbreviations for seconds")
        view.accessibilityIdentifier = "skip_back"
        return view
    }()
    
    private let skipForwardView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_forward", in: Bundle.audiobookToolkit(), compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        view.tintColor = NYPLColor.primaryTextColor
        view.subtext = NSLocalizedString("sec", bundle: Bundle.audiobookToolkit()!, value: "sec", comment: "Abbreviations for seconds")
        view.accessibilityIdentifier = "skip_forward"
        return view
    }()
    
    private let playImage = UIImage(
        named: "play",
        in: Bundle.audiobookToolkit(),
        compatibleWith: nil
    )?.withRenderingMode(.alwaysTemplate)

    private let pauseImage = UIImage(
        named: "pause",
        in: Bundle.audiobookToolkit(),
        compatibleWith: nil
    )?.withRenderingMode(.alwaysTemplate)
    
    private let playButton: ImageControlView = { () -> ImageControlView in
        let imageView = ImageControlView()
        imageView.accessibilityIdentifier = "play_button"
        imageView.tintColor = NYPLColor.primaryTextColor
        return imageView
    }()

    private var regularConstraints: [NSLayoutConstraint]!
    private var compactConstraints: [NSLayoutConstraint]!

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public init() {
        super.init(frame: .zero)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        self.isAccessibilityElement = false

        self.addSubview(self.playButton)
        self.playButton.image = self.playImage
        self.playButton.autoAlignAxis(.vertical, toSameAxisOf: self)
        self.playButton.accessibilityLabel = NSLocalizedString("Play", bundle: Bundle.audiobookToolkit()!, value: "Play", comment: "Play")
        self.playButton.addTarget(self, action: #selector(PlaybackControlView.playButtonWasTapped(_:)), for: .touchUpInside)

        self.addSubview(self.skipBackView)
        self.skipBackView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipBackView.autoPinEdge(.left, to: .left, of: self, withOffset: 0)
        self.skipBackView.autoPinEdge(.top, to: .top, of: self)
        self.skipBackView.autoPinEdge(.bottom, to: .bottom, of: self)
        self.skipBackView.addTarget(self, action: #selector(PlaybackControlView.skipBackButtonWasTapped(_:)), for: .touchUpInside)

        self.addSubview(self.skipForwardView)
        self.skipForwardView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipForwardView.autoPinEdge(.right, to: .right, of: self, withOffset: 0)
        self.skipForwardView.autoPinEdge(.top, to: .top, of: self)
        self.skipForwardView.autoPinEdge(.bottom, to: .bottom, of: self)
        self.skipForwardView.addTarget(self, action: #selector(PlaybackControlView.skipForwardButtonWasTapped(_:)), for: .touchUpInside)

        self.skipBackView.text = "\(self.skipBackValue)"
        let skipBackFormat = NSLocalizedString("Rewind %d seconds", bundle: Bundle.audiobookToolkit()!, value: "Rewind %d seconds", comment: "Rewind a configurable number of seconds")
        self.skipBackView.accessibilityLabel = String(format: skipBackFormat, self.skipBackValue)

        self.skipForwardView.text = "\(self.skipForwardValue)"
        let skipFrowardFormat = NSLocalizedString("Fast Forward %d seconds", bundle: Bundle.audiobookToolkit()!, value: "Fast Forward %d seconds", comment: "Fast forward a configurable number of seconds")
        self.skipForwardView.accessibilityLabel = String(format: skipFrowardFormat, self.skipForwardValue)

        compactConstraints = NSLayoutConstraint.autoCreateConstraintsWithoutInstalling {
            self.playButton.autoSetDimensions(to: CGSize(width: 56, height: 56))
            self.skipBackView.autoSetDimensions(to: CGSize(width: 66, height: 66))
            self.skipForwardView.autoSetDimensions(to: CGSize(width: 66, height: 66))
            self.skipBackView.autoPinEdge(.right, to: .left, of: self.playButton, withOffset: -self.horizontalPadding)
            self.skipForwardView.autoPinEdge(.left, to: .right, of: self.playButton, withOffset: self.horizontalPadding)
        }

        regularConstraints = NSLayoutConstraint.autoCreateConstraintsWithoutInstalling {
            self.playButton.autoSetDimensions(to: CGSize(width: 80, height: 80))
            self.skipBackView.autoSetDimensions(to: CGSize(width: 96, height: 96))
            self.skipForwardView.autoSetDimensions(to: CGSize(width: 96, height: 96))
            self.skipBackView.autoPinEdge(.right, to: .left, of: self.playButton, withOffset: -self.horizontalPadding * 2)
            self.skipForwardView.autoPinEdge(.left, to: .right, of: self.playButton, withOffset: self.horizontalPadding * 2)
        }
      
        enableConstraints() // iOS < 13 used to guarantee `traitCollectionDidChange` was called, but not anymore
    }

    @objc public func playButtonWasTapped(_ sender: Any) {
        self.togglePlayPauseButtonUIState()
        if self.playButton.image == self.pauseImage {
            self.delegate?.playbackControlViewPlayButtonWasTapped(self)
        } else {
            self.delegate?.playbackControlViewPauseButtonWasTapped(self)
        }
    }

    @objc public func skipBackButtonWasTapped(_ sender: Any) {
        self.delegate?.playbackControlViewSkipBackButtonWasTapped(self)
    }

    @objc public func skipForwardButtonWasTapped(_ sender: Any) {
        self.delegate?.playbackControlViewSkipForwardButtonWasTapped(self)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        enableConstraints()
    }

    func enableConstraints() {
        if traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .regular {
            if compactConstraints.count > 0 && compactConstraints[0].isActive {
                NSLayoutConstraint.deactivate(compactConstraints)
            }
            NSLayoutConstraint.activate(regularConstraints)
        } else {
            if regularConstraints.count > 0 && regularConstraints[0].isActive {
                NSLayoutConstraint.deactivate(regularConstraints)
            }
            NSLayoutConstraint.activate(compactConstraints)
        }
    }
}
