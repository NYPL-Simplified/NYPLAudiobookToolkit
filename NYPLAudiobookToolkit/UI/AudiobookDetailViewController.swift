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

    private let audiobookManager: AudiobookManager
    private var currentChapter: ChapterLocation? {
        return self.audiobookManager.audiobook.player.currentChapterLocation
    }

    public required init(audiobookManager: AudiobookManager) {
        self.audiobookManager = audiobookManager
        self.tintColor = UIColor.red
        super.init(nibName: nil, bundle: nil)
        self.audiobookManager.timerDelegate = self
        self.audiobookManager.downloadDelegate = self
        self.audiobookManager.audiobook.player.registerDelegate(self)
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
    private let sleepTimerDefaultText = "☾"
    private let sleepTimerDefaultAccessibilityLabel = "Sleep Timer"
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

        let gradiant = CAGradientLayer()
        gradiant.frame = self.view.bounds
        let startColor = UIColor(red: (210 / 255), green: (217 / 255), blue: (221 / 255), alpha: 1).cgColor
        gradiant.colors = [ startColor, UIColor.white.cgColor]
        gradiant.startPoint = CGPoint.zero
        gradiant.endPoint = CGPoint(x: 1, y: 1)
        self.view.layer.insertSublayer(gradiant, at: 0)
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
        bbi.accessibilityLabel = "Table Of Contents"
        self.navigationItem.rightBarButtonItem = bbi
    
        self.view.addSubview(self.chapterInfoStack)
        self.chapterInfoStack.autoPin(toTopLayoutGuideOf: self, withInset: self.padding)
        self.chapterInfoStack.autoPinEdge(.left, to: .left, of: self.view)
        self.chapterInfoStack.autoPinEdge(.right, to: .right, of: self.view)

        self.chapterInfoStack.titleText = self.audiobookManager.metadata.title
        self.chapterInfoStack.authors = self.audiobookManager.metadata.authors

        self.view.addSubview(self.seekBar)
        self.seekBar.delegate = self;
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.chapterInfoStack, withOffset: self.padding * 2)
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.chapterInfoStack, withOffset: self.padding, relation: .greaterThanOrEqual)
        self.seekBar.autoPinEdge(.left, to: .left, of: self.view, withOffset: self.padding * 2)
        self.seekBar.autoPinEdge(.right, to: .right, of: self.view, withOffset: -(self.padding * 2))

        self.view.addSubview(self.coverView)
        self.coverView.autoPinEdge(.top, to: .bottom, of: self.seekBar, withOffset: self.padding * 2, relation: .greaterThanOrEqual)
        self.coverView.autoPinEdge(.top, to: .bottom, of: self.seekBar, withOffset: self.padding * 4, relation: .lessThanOrEqual)
        self.coverView.autoMatch(.width, to: .height, of: self.coverView, withMultiplier: 1)
        self.coverView.autoAlignAxis(.vertical, toSameAxisOf: self.view)

        self.view.addSubview(self.playbackControlView)
        self.view.addSubview(self.toolbar)

        self.playbackControlView.delegate = self
        self.playbackControlView.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: (self.padding * 2), relation: .greaterThanOrEqual)
        self.playbackControlView.autoPinEdge(.bottom, to: .top, of: self.toolbar, withOffset: -(self.padding * 2))
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
        let playbackSpeedText = HumanReadablePlaybackRate(rate: self.audiobookManager.audiobook.player.playbackRate).value
        let speed =  UIBarButtonItem(
            title: playbackSpeedText,
            style: .plain,
            target: self,
            action: #selector(AudiobookDetailViewController.speedWasPressed(_:))
        )
        speed.accessibilityLabel = "Playback speed \(playbackSpeedText)"
        speed.tintColor = self.tintColor
        items.insert(speed, at: self.speedBarButtonIndex)

        let audioRoutingItem = self.audioRoutingBarButtonItem()
        items.insert(audioRoutingItem, at: self.audioRoutingBarButtonIndex)
        let sleepTimer = UIBarButtonItem(
            title: self.sleepTimerDefaultText,
            style: .plain,
            target: self,
            action: #selector(AudiobookDetailViewController.sleepTimerWasPressed(_:))
        )
        sleepTimer.tintColor = self.tintColor
        sleepTimer.accessibilityLabel = self.sleepTimerDefaultAccessibilityLabel

        items.insert(sleepTimer, at: self.sleepTimerBarButtonIndex)
        self.toolbar.setItems(items, animated: true)

        if let currentChapter = self.currentChapter {
            let timeLeftAfterCurrentChapter = self.timeLeftAfter(chapter: currentChapter)
            self.seekBar.setOffset(
                currentChapter.playheadOffset,
                duration: currentChapter.duration,
                timeLeftInBook: timeLeftAfterCurrentChapter,
                middleText: "Chapter \(currentChapter.number) of \(self.audiobookManager.audiobook.spine.count)"
            )
        }
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
        func actionFrom(rate: PlaybackRate, player: Player) -> UIAlertAction {
            let handler = { (_ action: UIAlertAction) -> Void in
                player.playbackRate = rate
                self.speedButtonShouldUpdate(rate: rate)
            }
            let title = HumanReadablePlaybackRate(rate: rate).value
            return UIAlertAction(title: title, style: .default, handler: handler)
        }
        
        let actionSheet = UIAlertController(title: "Set Your Play Speed", message: nil, preferredStyle: .actionSheet)
        let triggers: [PlaybackRate] = [.threeQuartersTime, .normalTime, .oneAndAQuarterTime, .oneAndAHalfTime, .doubleTime ]
        triggers.forEach { (trigger)  in
            let alert = actionFrom(rate: trigger, player: self.audiobookManager.audiobook.player)
            actionSheet.addAction(alert)
        }
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
    }

    func speedButtonShouldUpdate(rate: PlaybackRate) {
        if let buttonItem = self.toolbar.items?[self.speedBarButtonIndex] {
            let playbackSpeedText = HumanReadablePlaybackRate(rate: rate).value
            buttonItem.title = playbackSpeedText
            buttonItem.accessibilityLabel = "Playback speed \(playbackSpeedText)"
        }
    }
    
    @objc public func sleepTimerWasPressed(_ sender: Any) {
        func actionFrom(trigger: SleepTimerTriggerAt, sleepTimer: SleepTimer) -> UIAlertAction {
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
            let alert = actionFrom(trigger: trigger, sleepTimer: self.audiobookManager.sleepTimer)
            actionSheet.addAction(alert)
        }
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
    }

    @objc func coverArtWasPressed(_ sender: Any) { }
    
    func updateControlsForPlaybackStart() {
        self.playbackControlView.showPauseButton()
    }

    func updateControlsForPlaybackStop() {
        self.playbackControlView.showPlayButton()
    }
    
    func audioRoutingBarButtonItem() -> UIBarButtonItem {
        let view: UIView
        if #available(iOS 11.0, *) {
            view = AVRoutePickerView()
        } else {
            let volumeView = MPVolumeView()
            volumeView.showsVolumeSlider = false
            volumeView.showsRouteButton = true
            volumeView.sizeToFit()
            view = volumeView
        }
        view.tintColor = self.tintColor
        let buttonItem = UIBarButtonItem(customView: view)
        buttonItem.isAccessibilityElement = true
        buttonItem.accessibilityLabel = "Airplay"
        buttonItem.accessibilityTraits = UIAccessibilityTraitButton
        return buttonItem
    }
    
    func updateTemporalUIElements() {
        if let chapter = self.currentChapter {
            let timeLeftInBook = self.timeLeftAfter(chapter: chapter)
            self.seekBar.setOffset(
                chapter.playheadOffset,
                duration: chapter.duration,
                timeLeftInBook: timeLeftInBook,
                middleText: "Chapter \(chapter.number) of \(self.audiobookManager.audiobook.spine.count)"
            )
        }
        
        if let barButtonItem = self.toolbar.items?[self.sleepTimerBarButtonIndex] {
            if self.audiobookManager.sleepTimer.isScheduled {
                let title = HumanReadableTimestamp(timeInterval: self.audiobookManager.sleepTimer.timeRemaining).value
                barButtonItem.title = title
                let voiceOverTimeRemaining = VoiceOverTimestamp(timeInterval: self.audiobookManager.sleepTimer.timeRemaining).value
                barButtonItem.accessibilityLabel = "\(voiceOverTimeRemaining) until playback pauses"
            } else {
                if self.sleepTimerDefaultText != barButtonItem.title {
                    barButtonItem.title = self.sleepTimerDefaultText
                    barButtonItem.accessibilityLabel = self.sleepTimerDefaultAccessibilityLabel
                }
            }
        }
    }
}

extension AudiobookDetailViewController: AudiobookManagerTimerDelegate {
    public func audiobookManager(_ audiobookManager: AudiobookManager, didUpdate timer: Timer?) {
        self.updateTemporalUIElements()
    }
}

extension AudiobookDetailViewController: PlaybackControlViewDelegate {
    func playbackControlViewSkipBackButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.audiobookManager.audiobook.player.skipBack()
    }
    
    func playbackControlViewSkipForwardButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.audiobookManager.audiobook.player.skipForward()
    }
    
    // Pausing happens almost instantly so we ask the manager to pause and pause the seek bar at the same time. However playback can take time to start up and we need to wait to move the seek bar until we here playback has began from the manager. This is because playing could require downloading the track.
    func playbackControlViewPlayButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        if self.audiobookManager.audiobook.player.isPlaying {
            self.audiobookManager.audiobook.player.pause()
            self.updateControlsForPlaybackStop()
        } else {
            self.audiobookManager.audiobook.player.play()
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

extension AudiobookDetailViewController: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.updateUIWithChapter(chapter, scrubbing: true)
    }
    
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.updateUIWithChapter(chapter, scrubbing: false)
    }
    
    func updateUIWithChapter(_ chapter: ChapterLocation, scrubbing: Bool) {
        self.chapterInfoStack.authors = self.audiobookManager.metadata.authors
        let timeLeftAfterChapter = self.timeLeftAfter(chapter: chapter)
        self.seekBar.setOffset(
            chapter.playheadOffset,
            duration: chapter.duration,
            timeLeftInBook: timeLeftAfterChapter,
            middleText: "Chapter \(chapter.number) of \(self.audiobookManager.audiobook.spine.count)"
        )
        if scrubbing {
            self.updateControlsForPlaybackStart()
        } else {
            self.updateControlsForPlaybackStop()
        }
    }
}

extension AudiobookDetailViewController: ScrubberViewDelegate {
    func scrubberView(_ scrubberView: ScrubberView, didRequestScrubTo offset: TimeInterval) {
        if let chapter = self.currentChapter?.chapterWith(offset) {
            self.audiobookManager.audiobook.player.jumpToLocation(chapter)
        }
    }

    func scrubberViewDidRequestAccessibilityIncrement(_ scrubberView: ScrubberView) {
        self.audiobookManager.audiobook.player.skipForward()
    }

    func scrubberViewDidRequestAccessibilityDecrement(_ scrubberView: ScrubberView) {
        self.audiobookManager.audiobook.player.skipBack()
    }
}

