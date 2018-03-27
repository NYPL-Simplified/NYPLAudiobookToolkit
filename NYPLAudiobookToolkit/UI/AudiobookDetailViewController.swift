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
import AVKit
import MediaPlayer

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
    private var currentChapter: ChapterLocation? {
        return audiobookManager.currentChapterLocation
    }

    public required init(audiobookManager: AudiobookManager) {
        self.audiobookManager = audiobookManager

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
    private let speedBarButtonIndex = 1
    private let sleepTimerBarButtonIndex = 5
    private let audioRoutingBarButtonIndex = 3
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
    private weak var timer: Timer?
    
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
        var items: [UIBarButtonItem] = [flexibleSpace, flexibleSpace, flexibleSpace, flexibleSpace]
        let speed =  UIBarButtonItem(
            title: HumanReadablePlaybackRate(rate: self.audiobookManager.playbackRate).value,
            style: .plain,
            target: self,
            action: #selector(AudiobookDetailViewController.speedWasPressed(_:))
        )
        speed.tintColor = self.tintColor
        items.insert(speed, at: self.speedBarButtonIndex)
        
        let audioRoutingItem = self.audioRoutingBarButtonItem()
        items.insert(audioRoutingItem, at: self.audioRoutingBarButtonIndex)
        let sleepTimer = UIBarButtonItem(
            title: "☾",
            style: .plain,
            target: self,
            action: #selector(AudiobookDetailViewController.sleepTimerWasPressed(_:))
        )
        sleepTimer.tintColor = self.tintColor
        items.insert(sleepTimer, at: self.sleepTimerBarButtonIndex)
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
        
        self.timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(AudiobookDetailViewController.updateTemporalUIElements(_:)),
            userInfo: nil,
            repeats: true
        )
    }
    
    func timeLeftAfter(chapter: ChapterLocation) -> TimeInterval {
        let spine = self.audiobookManager.audiobook.spine
        var addUpStuff = false
        let timeLeftInChapter = chapter.duration - chapter.playheadOffset
        let timeLeftAfterChapter = spine.reduce(timeLeftInChapter, { (result, element) -> TimeInterval in
            var newResult: TimeInterval = 0
            if addUpStuff {
                newResult = result + element.chapter.duration
            }

            if element.chapter.inSameChapter(other: self.currentChapter) {
                newResult = timeLeftInChapter
                addUpStuff = true
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
        func alertFrom(rate: PlaybackRate, manager: AudiobookManager) -> UIAlertAction {
            let handler = { (_ action: UIAlertAction) -> Void in
                manager.playbackRate = rate
                self.speedButtonShouldUpdate(rate: rate)
            }
            let title = HumanReadablePlaybackRate(rate: rate).value
            return UIAlertAction(title: title, style: .default, handler: handler)
        }
        
        let actionSheet = UIAlertController(title: "Set Your Play Speed", message: nil, preferredStyle: .actionSheet)
        let triggers: [PlaybackRate] = [.threeQuartersTime, .normalTime, .oneAndAQuarterTime, .oneAndAHalfTime, .doubleTime ]
        triggers.forEach { (trigger)  in
            let alert = alertFrom(rate: trigger, manager: self.audiobookManager)
            actionSheet.addAction(alert)
        }
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
    }

    func speedButtonShouldUpdate(rate: PlaybackRate) {
        if let buttonItem = self.toolbar.items?[self.speedBarButtonIndex] {
            buttonItem.title = HumanReadablePlaybackRate(rate: rate).value
        }
    }
    
    @objc public func sleepTimerWasPressed(_ sender: Any) {
        func alertFromsleepTimer(trigger: SleepTimerTriggerAt, sleepTimer: SleepTimer) -> UIAlertAction {
            let handler = { (_ action: UIAlertAction) -> Void in
                sleepTimer.setTimerTo(trigger: trigger)
            }
            var action: UIAlertAction! = nil
            switch trigger {
            case .endOfChapter:
                action = UIAlertAction(title: "End of Chapter", style: .default, handler: handler)
            case .oneHour:
                action = UIAlertAction(title: "60", style: .default, handler: handler)
            case .thirtyMinutes:
                action = UIAlertAction(title: "30", style: .default, handler: handler)
            case .fifteenMinutes:
                action = UIAlertAction(title: "15", style: .default, handler: handler)
            case .never:
                action = UIAlertAction(title: "Off", style: .default, handler: handler)
            }
            return action
        }
        
        let actionSheet = UIAlertController(title: "Set Your Sleep Timer", message: nil, preferredStyle: .actionSheet)
        let triggers: [SleepTimerTriggerAt] = [.never, .fifteenMinutes, .thirtyMinutes, .oneHour, .endOfChapter]
        triggers.forEach { (trigger)  in
            let alert = alertFromsleepTimer(trigger: trigger, sleepTimer: self.audiobookManager.sleepTimer)
            actionSheet.addAction(alert)
        }
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
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
    
    func audioRoutingBarButtonItem() -> UIBarButtonItem {
        var view: UIView! = nil
        if #available(iOS 11.0, *) {
            view = AVRoutePickerView()
        } else {
            let volumeView = MPVolumeView()
            volumeView.showsVolumeSlider = false
            volumeView.showsRouteButton = true
            volumeView.sizeToFit()
        }
        return UIBarButtonItem(customView: view)
    }
    
    @objc func updateTemporalUIElements(_ timer: Timer) {
        if let chapter = self.currentChapter {
            let timeLeftInBook = self.timeLeftAfter(chapter: chapter)
            self.seekBar.setOffset(
                chapter.playheadOffset,
                duration: chapter.duration,
                timeLeftInBook: timeLeftInBook
            )
        }
        
        if let barButtonItem = self.toolbar.items?[self.sleepTimerBarButtonIndex] {
            if self.audiobookManager.sleepTimer.isScheduled {
                let title = HumanReadableTimeStamp(timeInterval: self.audiobookManager.sleepTimer.timeRemaining).value
                barButtonItem.title = title
            } else {
                barButtonItem.title = "☾"
            }

        }
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

    func scrubberViewDidRequestUpdate(_ scrubberView: ScrubberView) {

    }
}

