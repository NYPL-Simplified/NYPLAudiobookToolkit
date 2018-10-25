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

    private var horizontalPadding = CGFloat(25)
    private let skipBackView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_back", in: Bundle.audiobookToolkit(), compatibleWith: nil)
        view.subtext = NSLocalizedString("sec", bundle: Bundle.audiobookToolkit()!, value: "sec", comment: "Abbreviations for seconds")
        view.accessibilityIdentifier = "skip_back"
        return view
    }()
    
    private let skipForwardView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_forward", in: Bundle.audiobookToolkit(), compatibleWith: nil)
        view.subtext = NSLocalizedString("sec", bundle: Bundle.audiobookToolkit()!, value: "sec", comment: "Abbreviations for seconds")
        view.accessibilityIdentifier = "skip_forward"
        return view
    }()
    
    private let playImage = UIImage(
        named: "play",
        in: Bundle.audiobookToolkit(),
        compatibleWith: nil
    )

    private let pauseImage = UIImage(
        named: "pause",
        in: Bundle.audiobookToolkit(),
        compatibleWith: nil
    )
    
    private let playButton: ImageControlView = { () -> ImageControlView in
        let imageView = ImageControlView()
        imageView.accessibilityIdentifier = "play_button"
        return imageView
    }()

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
        self.playButton.autoSetDimensions(to: CGSize(width: 56, height: 56))
        self.playButton.accessibilityLabel = NSLocalizedString("Play", bundle: Bundle.audiobookToolkit()!, value: "Play", comment: "Play")
        self.playButton.addTarget(self, action: #selector(PlaybackControlView.playButtonWasTapped(_:)), for: .touchUpInside)

        self.addSubview(self.skipBackView)
        self.skipBackView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipBackView.autoPinEdge(.right, to: .left, of: self.playButton, withOffset: -self.horizontalPadding)
        self.skipBackView.autoPinEdge(.left, to: .left, of: self, withOffset: 0)
        self.skipBackView.autoPinEdge(.top, to: .top, of: self)
        self.skipBackView.autoPinEdge(.bottom, to: .bottom, of: self)
        self.skipBackView.autoSetDimensions(to: CGSize(width: 66, height: 66))
        self.skipBackView.addTarget(self, action: #selector(PlaybackControlView.skipBackButtonWasTapped(_:)), for: .touchUpInside)

        self.addSubview(self.skipForwardView)
        self.skipForwardView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipForwardView.autoPinEdge(.left, to: .right, of: self.playButton, withOffset: self.horizontalPadding)
        self.skipForwardView.autoPinEdge(.right, to: .right, of: self, withOffset: 0)
        self.skipForwardView.autoPinEdge(.top, to: .top, of: self)
        self.skipForwardView.autoPinEdge(.bottom, to: .bottom, of: self)
        self.skipForwardView.autoSetDimensions(to: CGSize(width: 66, height: 66))
        self.skipForwardView.addTarget(self, action: #selector(PlaybackControlView.skipForwardButtonWasTapped(_:)), for: .touchUpInside)

        self.skipBackView.text = "\(self.skipBackValue)"
        let skipBackFormat = NSLocalizedString("Rewind %d seconds", bundle: Bundle.audiobookToolkit()!, value: "Rewind %d seconds", comment: "Rewind a configurable number of seconds")
        self.skipBackView.accessibilityLabel = String(format: skipBackFormat, self.skipBackValue)

        self.skipForwardView.text = "\(self.skipForwardValue)"
        let skipFrowardFormat = NSLocalizedString("Fast Forward %d seconds", bundle: Bundle.audiobookToolkit()!, value: "Fast Forward %d seconds", comment: "Fast forward a configurable number of seconds")
        self.skipForwardView.accessibilityLabel = String(format: skipFrowardFormat, self.skipForwardValue)
    }
    
    @objc public func playButtonWasTapped(_ sender: Any) {
        self.delegate?.playbackControlViewPlayButtonWasTapped(self)
    }

    @objc public func skipBackButtonWasTapped(_ sender: Any) {
        self.delegate?.playbackControlViewSkipBackButtonWasTapped(self)
    }

    @objc public func skipForwardButtonWasTapped(_ sender: Any) {
        self.delegate?.playbackControlViewSkipForwardButtonWasTapped(self)
    }
}
