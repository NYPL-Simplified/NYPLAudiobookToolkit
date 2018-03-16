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

    private let downloadCompleteText = "Title Downloaded!"
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

    private let chapterInfoStack = ChapterInfoStack()

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

        self.view.addSubview(self.coverView)
        self.coverView.autoPinEdge(.top, to: .bottom, of: self.chapterInfoStack)
        self.coverView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.autoSetDimensions(to: CGSize(width: 266, height: 266))
        
        self.view.addSubview(self.seekBar)
        self.seekBar.delegate = self;
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: self.padding)
        self.seekBar.autoPinEdge(.left, to: .left, of: self.view, withOffset: self.padding * 2)
        self.seekBar.autoPinEdge(.right, to: .right, of: self.view, withOffset: -(self.padding * 2))
        if let currentChapter = self.currentChapter {
            self.seekBar.setOffset(currentChapter.playheadOffset, duration: currentChapter.duration)
        }

        self.view.addSubview(self.playbackControlView)
        self.playbackControlView.delegate = self
        self.playbackControlView.autoPinEdge(.top, to: .bottom, of: self.seekBar, withOffset: self.padding)
        self.playbackControlView.autoPin(toBottomLayoutGuideOf: self, withInset: self.padding)
        self.playbackControlView.autoPinEdge(.left, to: .left, of: self.view, withOffset: 0, relation: .greaterThanOrEqual)
        self.playbackControlView.autoPinEdge(.right, to: .right, of: self.view, withOffset: 0, relation: .lessThanOrEqual)
        self.playbackControlView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(AudiobookDetailViewController.coverArtWasPressed(_:))
            )
        )
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
    public func audiobookManager(_ audiobookManager: AudiobookManager, didBecomeReadyForPlayback spineElement: SpineElement) {
        guard let currentChapter = self.currentChapter else { return }
        if spineElement.chapter.number == currentChapter.number && spineElement.chapter.part == currentChapter.part {
            self.chapterInfoStack.subtitleText = self.audiobookManager.metadata.authors.joined(separator: ", ")
            Timer.scheduledTimer(
                timeInterval: 3,
                target: self,
                selector: #selector(AudiobookDetailViewController.postPlaybackReadyTimerFired(_:)),
                userInfo: nil,
                repeats: false
            )
        }
    }
    
    @objc func postPlaybackReadyTimerFired(_ timer: Timer) {
        if self.chapterInfoStack.subtitleText == self.downloadCompleteText  {
            if let chapter = self.currentChapter {
                self.chapterInfoStack.subtitleText = "Chapter \(chapter.number)"
            } else {
                self.chapterInfoStack.subtitleText = self.audiobookManager.metadata.authors.joined(separator: ", ")
            }
        }
    }

    public func audiobookManager(_ audiobookManager: AudiobookManager, didUpdateDownloadPercentageFor spineElement: SpineElement) {
        self.chapterInfoStack.subtitleText = "Downloading \(Int(spineElement.downloadTask.downloadProgress * 100))%"
    }

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
        self.seekBar.setOffset(chapter.playheadOffset, duration: chapter.duration)
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
