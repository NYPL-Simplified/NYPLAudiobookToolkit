//
//  AudiobookViewController.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/11/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import Foundation
import PureLayout

public final class AudiobookDetailViewController: UIViewController {
    
    /// Light gray
    public var backgroundColor = UIColor(red: 219/255, green: 220/255, blue: 223/255, alpha: 1) {
        didSet {
            self.view.backgroundColor = self.backgroundColor
            self.navigationController?.navigationBar.barTintColor = self.backgroundColor
            self.playbackControlView.backgroundColor = self.backgroundColor
        }
    }

    private let audiobookManager: AudiobookManager
    private var currentChapter: ChapterLocation?
    public required init(audiobookManager: AudiobookManager) {
        self.audiobookManager = audiobookManager
        self.currentChapter = audiobookManager.currentChapterLocation
        self.tintColor = UIColor.red
        super.init(nibName: nil, bundle: nil)
        self.audiobookManager.downloadDelegate = self
        self.audiobookManager.playbackDelegate = self
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let padding = CGFloat(8)
    private let seekBar = ScrubberView()
    private let tintColor: UIColor
    private let playbackControlView = PlaybackControlView()
    private let coverView: UIImageView = { () -> UIImageView in
        let imageView = UIImageView()
        imageView.image = UIImage(named: "example_cover", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        imageView.isUserInteractionEnabled = true
        imageView.accessibilityIdentifier = "cover_art"
        imageView.layer.cornerRadius = 10
        imageView.layer.masksToBounds = true
        imageView.contentMode = UIViewContentMode.scaleAspectFill
        return imageView
    }()

    private let toolbar = UIToolbar()
    private let chapterInfoStack = ChapterInfoStack()
    private let toolbarHeight: CGFloat = 44
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.tintColor = self.tintColor

        self.playbackControlView.backgroundColor = self.backgroundColor
        self.view.backgroundColor = self.backgroundColor

        let tocImage = UIImage(
            named: "table_of_contents",
            in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"),
            compatibleWith: nil
        )
        let bbi = UIBarButtonItem(
            image: tocImage,
            style: .plain,
            target: self,
            action: #selector(AudiobookDetailViewController.tocWasPressed)
        )
        self.navigationItem.rightBarButtonItem = bbi
    
        self.view.addSubview(self.chapterInfoStack)
        self.chapterInfoStack.autoPin(toTopLayoutGuideOf: self, withInset: self.padding)
        self.chapterInfoStack.autoPinEdge(.left, to: .left, of: self.view)
        self.chapterInfoStack.autoPinEdge(.right, to: .right, of: self.view)
        self.chapterInfoStack.titleText = self.audiobookManager.metadata.title
        self.chapterInfoStack.subtitleText = self.audiobookManager.metadata.authors.joined(separator: ", ")

        
        self.view.addSubview(self.seekBar)
        self.seekBar.delegate = self;
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.chapterInfoStack, withOffset: self.padding)
        self.seekBar.autoPinEdge(.left, to: .left, of: self.view, withOffset: self.padding * 2)
        self.seekBar.autoPinEdge(.right, to: .right, of: self.view, withOffset: -(self.padding * 2))

        self.view.addSubview(self.coverView)
        self.coverView.autoPinEdge(.top, to: .bottom, of: self.seekBar, withOffset: self.padding * 2)
        self.coverView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.autoSetDimensions(to: CGSize(width: 191, height: 191))

        self.view.addSubview(self.playbackControlView)
        self.view.addSubview(self.toolbar)
        self.playbackControlView.delegate = self
        self.playbackControlView.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: self.padding * 3)
        self.playbackControlView.autoPinEdge(.bottom, to: .top, of: self.toolbar, withOffset: 0, relation: .lessThanOrEqual)
        self.playbackControlView.autoPinEdge(.left, to: .left, of: self.view, withOffset: 0, relation: .greaterThanOrEqual)
        self.playbackControlView.autoPinEdge(.right, to: .right, of: self.view, withOffset: 0, relation: .lessThanOrEqual)
        self.playbackControlView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(AudiobookDetailViewController.coverArtWasPressed(_:))
            )
        )

        self.toolbar.autoPin(toBottomLayoutGuideOf: self, withInset: 0)
        self.toolbar.autoPinEdge(.left, to: .left, of: self.view)
        self.toolbar.autoPinEdge(.right, to: .right, of: self.view)
        self.toolbar.autoSetDimension(.height, toSize: self.toolbarHeight)
        self.toolbar.layer.borderWidth = 1
        self.toolbar.layer.borderColor = UIColor.white.cgColor
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        var items: [UIBarButtonItem] = [flexibleSpace]
        let speed = self.barButtonWith(
            title: "Speed",
            imageNamed:"speed",
            target: self,
            action: #selector(AudiobookDetailViewController.speedWasPressed(_:))
        )
        if let speed = speed {
            items.append(speed)
        }
        items.append(flexibleSpace)
        let sleepTimer = self.barButtonWith(
            title: "Sleep Timer",
            imageNamed: "moon",
            target: self,
            action: #selector(AudiobookDetailViewController.sleepTimerWasPressed(_:))
        )
        if let sleepTimer = sleepTimer {
            items.append(sleepTimer)
        }
        items.append(flexibleSpace)
        self.toolbar.setItems(items, animated: true)

        if let currentChapter = self.currentChapter {
            let timeLeftAfterCurrentChapter = self.timeLeftAfter(chapter: currentChapter)
            self.seekBar.setOffset(
                currentChapter.playheadOffset,
                duration: currentChapter.duration,
                timeLeftInBook: timeLeftAfterCurrentChapter
            )
            self.seekBar.setMiddle(text: "Chapter \(currentChapter.number) of \(self.audiobookManager.audiobook.spine.count)")
        }
    }
    
    func timeLeftAfter(chapter: ChapterLocation) -> TimeInterval {
        let spine = self.audiobookManager.audiobook.spine
        var addUpStuff = false
        let timeLeftInChapter = chapter.duration - chapter.playheadOffset
        let timeLeftAfterChapter = spine.reduce(timeLeftInChapter, { (result, element) -> TimeInterval in
            if element.chapter.inSameChapter(other: currentChapter) {
                addUpStuff = true
            }
            var newResult: TimeInterval = 0
            if addUpStuff {
                newResult = result + element.chapter.duration
            }
            return newResult
        })
        return timeLeftAfterChapter
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @objc public func tocWasPressed(_ sender: Any) {
        let tbvc = AudiobookTableOfContentsTableViewController(tableOfContents: self.audiobookManager.tableOfContents)
        self.navigationController?.pushViewController(tbvc, animated: true)
    }

    
    @objc public func speedWasPressed(_ sender: Any) {
    }

    
    @objc public func sleepTimerWasPressed(_ sender: Any) {
    }

    @objc func coverArtWasPressed(_ sender: Any) {
        self.audiobookManager.fetch()
    }
    
    func updateControlsForPlaybackStart() {
        self.seekBar.play()
        self.playbackControlView.showPauseButton()
    }

    func updateControlsForPlaybackStop() {
        self.seekBar.pause()
        self.playbackControlView.showPlayButton()
    }
    
    // `UIBarButtonItem`s do not allow for both an image and a title, despite its sybling `UITabBarItem` being
    // able to support this feature. The mess you see below is to allow for bar button items that support
    // both at the same time.
    //
    // Please forgive the hardcoded values. This was truly a last resort.
    private func barButtonWith(title: String, imageNamed: String, target: Any?, action: Selector) -> UIBarButtonItem? {
        guard let image = UIImage(named: imageNamed, in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil) else {
            return nil
        }
        let view = UIView()
        let label = UILabel()

        let viewHeight: CGFloat = self.toolbarHeight
        let labelHeight: CGFloat = 16
        view.addSubview(label)
        label.text = title
        label.textColor = UIColor.darkText
        label.font = UIFont.systemFont(ofSize: 12)

        // Find the width of the label for the text provided
        let labelSize = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: labelHeight))
        
        // Place the label in its view
        let labelPoint = CGPoint(x: 0, y: viewHeight - labelHeight)
        let labelFrame = CGRect(origin: labelPoint, size: labelSize)
    
        let imageView = UIImageView(image: image)
        view.addSubview(imageView)
        let imageHeight: CGFloat = 24
        
        // Place the image in the middle of the text
        let imageXValue = (labelSize.width / 2) - (imageHeight / 2)
        
        // Place the image above the text
        let imageYValye = viewHeight - (labelHeight + imageHeight)
        let imageViewFrame = CGRect(
            x: imageXValue,
            y: imageYValye,
            width: imageHeight,
            height: imageHeight
        )
        imageView.contentMode = .scaleAspectFit
        imageView.frame = imageViewFrame
        label.frame = labelFrame
        view.frame = CGRect(
            x: 0,
            y: 0,
            width: labelFrame.width,
            height: viewHeight
        )
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: target, action: action))
        return UIBarButtonItem(customView: view)
    }
}

extension AudiobookDetailViewController: PlaybackControlViewDelegate {
    func playbackControlViewSkipBackButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.audiobookManager.skipBack()
    }
    
    func playbackControlViewSkipForwardButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.audiobookManager.skipForward()
    }
    
    // Pausing happens almost instantly so we ask the manager to pause and pause the seek bar at the same time. However playback can take time to start up and we need to wait to move the seek bar until we here playback has began from the manager. This is because playing could require downloading the track.
    func playbackControlViewPlayButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        if self.audiobookManager.isPlaying {
            self.audiobookManager.pause()
            self.updateControlsForPlaybackStop()
        } else {
            self.audiobookManager.play()
        }
    }
}

extension AudiobookDetailViewController: AudiobookManagerDownloadDelegate {
    public func audiobookManager(_ audiobookManager: AudiobookManager, didBecomeReadyForPlayback spineElement: SpineElement) { }
    public func audiobookManager(_ audiobookManager: AudiobookManager, didUpdateDownloadPercentageFor spineElement: SpineElement) { }
    public func audiobookManager(_ audiobookManager: AudiobookManager, didReceive error: NSError, for spineElement: SpineElement) {
        let alertController = UIAlertController(
            title: "Error!",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        self.present(alertController, animated: false, completion: nil)
    }
}

extension AudiobookDetailViewController: AudiobookManagerPlaybackDelegate {
    public func audiobookManager(_ audiobookManager: AudiobookManager, didBeginPlaybackOf chapter: ChapterLocation) {
        self.updateUIWithChapter(chapter, scrubbing: true)
    }

    public func audiobookManager(_ audiobookManager: AudiobookManager, didStopPlaybackOf chapter: ChapterLocation) {
        self.updateUIWithChapter(chapter, scrubbing: false)
    }
    
    func updateUIWithChapter(_ chapter: ChapterLocation, scrubbing: Bool) {
        self.currentChapter = chapter
        self.chapterInfoStack.subtitleText = self.audiobookManager.metadata.authors.joined(separator: ", ")
        let timeLeftAfterChapter = self.timeLeftAfter(chapter: chapter)
        self.seekBar.setOffset(
            chapter.playheadOffset,
            duration: chapter.duration,
            timeLeftInBook: timeLeftAfterChapter
        )
        if scrubbing {
            self.updateControlsForPlaybackStart()
            self.seekBar.play()
        } else {
            self.updateControlsForPlaybackStop()
            self.seekBar.pause()
        }
    }
}

extension AudiobookDetailViewController: ScrubberViewDelegate {
    func scrubberView(_ scrubberView: ScrubberView, didRequestScrubTo offset: TimeInterval) {
        scrubberView.pause()
        if let chapter = self.currentChapter?.chapterWith(offset) {
            self.audiobookManager.updatePlaybackWith(chapter)
        }
    }
}

