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
    
    public func showPlayButton () {
        self.playButton.image = self.playImage
    }
    
    public func showPauseButton () {
        self.playButton.image = self.pauseImage
    }

    private let padding = CGFloat(8)
    private let skipBackView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_back", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        view.text = "15"
        view.subtext = "sec"
        view.accessibilityIdentifier = "skip_back"
        return view
    }()
    
    private let skipForwardView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_forward", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        view.text = "15"
        view.subtext = "sec"
        view.accessibilityIdentifier = "skip_forward"
        return view
    }()
    
    private let playImage = UIImage(
        named: "play",
        in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"),
        compatibleWith: nil
    )

    private let pauseImage = UIImage(
        named: "pause",
        in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"),
        compatibleWith: nil
    )
    private let playButton: UIImageView = { () -> UIImageView in
        let imageView = UIImageView()
        imageView.accessibilityIdentifier = "play_button"
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
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
        self.addSubview(self.playButton)
        self.playButton.image = self.playImage
        self.playButton.autoAlignAxis(.vertical, toSameAxisOf: self)
        self.playButton.autoSetDimensions(to: CGSize(width: 56, height: 56))
        self.playButton.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(PlaybackControlView.playButtonWasTapped(_:))
            )
        )
        
        self.addSubview(self.skipBackView)
        self.skipBackView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipBackView.autoPinEdge(.right, to: .left, of: self.playButton, withOffset: -self.padding * 2)
        self.skipBackView.autoPinEdge(.left, to: .left, of: self, withOffset: 0)
        self.skipBackView.autoSetDimensions(to: CGSize(width: 66, height: 66))
        self.skipBackView.autoPinEdge(.top, to: .top, of: self)
        self.skipBackView.autoPinEdge(.bottom, to: .bottom, of: self)
        self.skipBackView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(PlaybackControlView.skipBackButtonWasTapped(_:))
            )
        )

        self.addSubview(self.skipForwardView)
        self.skipForwardView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipForwardView.autoPinEdge(.left, to: .right, of: self.playButton, withOffset: self.padding * 2)
        self.skipForwardView.autoPinEdge(.right, to: .right, of: self, withOffset: 0)
        self.skipForwardView.autoPinEdge(.top, to: .top, of: self)
        self.skipForwardView.autoPinEdge(.bottom, to: .bottom, of: self)
        self.skipForwardView.autoSetDimensions(to: CGSize(width: 66, height: 66))
        self.skipForwardView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(PlaybackControlView.skipForwardButtonWasTapped(_:))
            )
        )
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
