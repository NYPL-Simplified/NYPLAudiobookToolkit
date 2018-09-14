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

public final class AudiobookPlayerViewController: UIViewController {
    private let audiobookManager: AudiobookManager
    private var currentChapter: ChapterLocation? {
        return self.audiobookManager.audiobook.player.currentChapterLocation
    }

    @objc public required init(audiobookManager: AudiobookManager) {
        self.audiobookManager = audiobookManager
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    private let gradiant = CAGradientLayer()
    private let padding = CGFloat(8)
    private let seekBar = ScrubberView()
    private let playbackControlView = PlaybackControlView()
    private let speedBarButtonIndex = 1
    private let sleepTimerBarButtonIndex = 5
    private let audioRoutingBarButtonIndex = 3
    private let sleepTimerDefaultText = "☾"
    private let sleepTimerDefaultAccessibilityLabel = NSLocalizedString("Sleep Timer", bundle: Bundle.audiobookToolkit()!, value: "Sleep Timer", comment:"Sleep Timer")
    private let coverView: UIImageView = { () -> UIImageView in
        let imageView = UIImageView()
        imageView.image = UIImage(named: "example_cover", in: Bundle.audiobookToolkit(), compatibleWith: nil)
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
    private var waitingForPlayer = false
    private var waitingToTogglePlayPause = false
    override public func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.isTranslucent = false

        self.gradiant.frame = self.view.bounds
        let startColor = UIColor(red: (210 / 255), green: (217 / 255), blue: (221 / 255), alpha: 1).cgColor
        self.gradiant.colors = [ startColor, UIColor.white.cgColor]
        self.gradiant.startPoint = CGPoint.zero
        self.gradiant.endPoint = CGPoint(x: 1, y: 1)
        self.view.layer.insertSublayer(self.gradiant, at: 0)

        let tocImage = UIImage(
            named: "table_of_contents",
            in: Bundle.audiobookToolkit(),
            compatibleWith: nil
        )
        let bbi = UIBarButtonItem(
            image: tocImage,
            style: .plain,
            target: self,
            action: #selector(AudiobookPlayerViewController.tocWasPressed)
        )

        self.activityIndicator.hidesWhenStopped = true
        let indicatorBbi = UIBarButtonItem(customView: self.activityIndicator)
        self.navigationItem.rightBarButtonItems = [ bbi, indicatorBbi ]

        self.chapterInfoStack.titleText = self.audiobookManager.metadata.title
        self.chapterInfoStack.authors = self.audiobookManager.metadata.authors

        self.view.addSubview(self.chapterInfoStack)

        self.chapterInfoStack.autoPinEdge(toSuperviewEdge: .top, withInset: self.padding, relation: .greaterThanOrEqual)
        self.chapterInfoStack.autoAlignAxis(toSuperviewAxis: .vertical)

        self.view.addSubview(self.coverView)

        self.coverView.autoCenterInSuperview()
        self.coverView.autoMatch(.width, to: .height, of: self.coverView, withMultiplier: 1)

        let playbackControlViewContainer = UIView()
        playbackControlViewContainer.addSubview(self.playbackControlView)
        self.view.addSubview(playbackControlViewContainer)
        self.view.addSubview(self.toolbar)

        self.playbackControlView.delegate = self
        self.playbackControlView.autoCenterInSuperview()
        self.playbackControlView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0, relation: .greaterThanOrEqual)
        self.playbackControlView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0, relation: .greaterThanOrEqual)
        self.playbackControlView.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        self.playbackControlView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)

        playbackControlViewContainer.autoPinEdge(toSuperviewEdge: .left)
        playbackControlViewContainer.autoPinEdge(toSuperviewEdge: .right)
        playbackControlViewContainer.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: (self.padding * 2))
        playbackControlViewContainer.autoPinEdge(.bottom, to: .top, of: self.toolbar, withOffset: -(self.padding * 2))

        let seekBarContainerView = UIView()
        self.view.addSubview(seekBarContainerView)

        seekBarContainerView.autoPinEdge(.top, to: .bottom, of: self.chapterInfoStack, withOffset: self.padding * 2)
        seekBarContainerView.autoPinEdge(.bottom, to: .top, of: self.coverView, withOffset: -self.padding * 2)
        seekBarContainerView.autoPinEdge(toSuperviewEdge: .leading)
        seekBarContainerView.autoPinEdge(toSuperviewEdge: .trailing)

        seekBarContainerView.addSubview(self.seekBar)

        self.seekBar.delegate = self;
        self.seekBar.autoCenterInSuperview()
        self.seekBar.autoPinEdge(toSuperviewEdge: .leading, withInset: self.padding * 4, relation: .greaterThanOrEqual)
        self.seekBar.autoPinEdge(toSuperviewEdge: .trailing, withInset: self.padding * 4, relation: .greaterThanOrEqual)
        
        NSLayoutConstraint.autoSetPriority(.defaultHigh) {
            self.seekBar.autoSetDimension(.width, toSize: 500)
            self.seekBar.autoPinEdge(.top, to: .bottom, of: self.chapterInfoStack, withOffset: self.padding * 6)
            if (self.view.traitCollection.horizontalSizeClass == .regular) {
                self.coverView.autoSetDimension(.width, toSize: 500)
            }
        }

        self.coverView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(AudiobookPlayerViewController.coverArtWasPressed(_:))
            )
        )
        guard let chapter = self.currentChapter else { return }

        self.toolbar.layer.borderWidth = 1
        self.toolbar.layer.borderColor = UIColor.white.cgColor
        self.toolbar.autoPin(toBottomLayoutGuideOf: self, withInset: 0)
        self.toolbar.autoPinEdge(.left, to: .left, of: self.view)
        self.toolbar.autoPinEdge(.right, to: .right, of: self.view)
        self.toolbar.autoSetDimension(.height, toSize: self.toolbarHeight)
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        var items: [UIBarButtonItem] = [flexibleSpace, flexibleSpace, flexibleSpace, flexibleSpace]
        let playbackSpeedText = HumanReadablePlaybackRate(rate: self.audiobookManager.audiobook.player.playbackRate).value
        let speed =  UIBarButtonItem(
            title: playbackSpeedText,
            style: .plain,
            target: self,
            action: #selector(AudiobookPlayerViewController.speedWasPressed(_:))
        )
        speed.accessibilityLabel = self.playbackSpeedTextFor(speedText: playbackSpeedText)
        speed.tintColor = self.view.tintColor
        items.insert(speed, at: self.speedBarButtonIndex)

        let audioRoutingItem = self.audioRoutingBarButtonItem()
        items.insert(audioRoutingItem, at: self.audioRoutingBarButtonIndex)
        let texts = self.textsFor(sleepTimer: self.audiobookManager.sleepTimer, chapter: chapter)
        let sleepTimer = UIBarButtonItem(
            title: texts.title,
            style: .plain,
            target: self,
            action: #selector(AudiobookPlayerViewController.sleepTimerWasPressed(_:))
        )
        sleepTimer.tintColor = self.view.tintColor
        sleepTimer.accessibilityLabel = texts.accessibilityLabel

        items.insert(sleepTimer, at: self.sleepTimerBarButtonIndex)
        self.toolbar.setItems(items, animated: true)
        self.seekBar.setOffset(
            chapter.playheadOffset,
            duration: chapter.duration,
            timeLeftInBook: self.timeLeftAfter(chapter: chapter),
            middleText: self.middleTextFor(chapter: chapter)
        )
    }
  
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.gradiant.frame = self.view.bounds
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.audiobookManager.timerDelegate = nil
        self.audiobookManager.audiobook.player.removeDelegate(self)
        self.audiobookManager.networkService.removeDelegate(self)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.audiobookManager.timerDelegate = self
        self.audiobookManager.audiobook.player.registerDelegate(self)
        self.audiobookManager.networkService.registerDelegate(self)

        self.waitingToTogglePlayPause = true
        if self.audiobookManager.audiobook.player.isPlaying {
            self.playbackControlView.showPauseButtonIfNeeded()
        } else {
            self.playbackControlView.showPlayButtonIfNeeded()
        }

        self.updateUI()
    }
    
    func timeLeftAfter(chapter: ChapterLocation) -> TimeInterval {
        let spine = self.audiobookManager.audiobook.spine
        var addUpStuff = false
        let timeLeftInChapter = chapter.timeRemaining
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
        
        let actionSheetTitle = NSLocalizedString("Set Your Play Speed", bundle: Bundle.audiobookToolkit()!, value: "Set Your Play Speed", comment: "Set Your Play Speed")
        let actionSheet = UIAlertController(title: actionSheetTitle, message: nil, preferredStyle: .actionSheet)
        let triggers: [PlaybackRate] = [.threeQuartersTime, .normalTime, .oneAndAQuarterTime, .oneAndAHalfTime, .doubleTime ]
        triggers.forEach { (trigger)  in
            let alert = actionFrom(rate: trigger, player: self.audiobookManager.audiobook.player)
            actionSheet.addAction(alert)
        }
        let cancelActionTitle = NSLocalizedString("Cancel", bundle: Bundle.audiobookToolkit()!, value: "Cancel", comment: "Cancel")
        actionSheet.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        actionSheet.popoverPresentationController?.barButtonItem = self.toolbar.items?[self.speedBarButtonIndex]
        actionSheet.popoverPresentationController?.sourceView = self.view
        self.present(actionSheet, animated: true, completion: nil)
    }

    func speedButtonShouldUpdate(rate: PlaybackRate) {
        if let buttonItem = self.toolbar.items?[self.speedBarButtonIndex] {
            let playbackSpeedText = HumanReadablePlaybackRate(rate: rate).value
            buttonItem.title = playbackSpeedText
            buttonItem.accessibilityLabel = self.playbackSpeedTextFor(speedText: playbackSpeedText)
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
                let title = NSLocalizedString("End of Chapter", bundle: Bundle.audiobookToolkit()!, value: "End of Chapter", comment: "End of Chapter")
                action = UIAlertAction(title: title, style: .default, handler: handler)
            case .oneHour:
                action = UIAlertAction(title: "60", style: .default, handler: handler)
            case .thirtyMinutes:
                action = UIAlertAction(title: "30", style: .default, handler: handler)
            case .fifteenMinutes:
                action = UIAlertAction(title: "15", style: .default, handler: handler)
            case .never:
                let title = NSLocalizedString("Off", bundle: Bundle.audiobookToolkit()!, value: "Off", comment: "Off")
                action = UIAlertAction(title: title, style: .default, handler: handler)
            }
            return action
        }
        let title = NSLocalizedString("Set Your Sleep Timer", bundle: Bundle.audiobookToolkit()!, value: "Set Your Sleep Timer", comment: "Set Your Sleep Timer")
        let actionSheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        let triggers: [SleepTimerTriggerAt] = [.never, .fifteenMinutes, .thirtyMinutes, .oneHour, .endOfChapter]
        triggers.forEach { (trigger)  in
            let alert = actionFrom(trigger: trigger, sleepTimer: self.audiobookManager.sleepTimer)
            actionSheet.addAction(alert)
        }
        let cancelActionTitle = NSLocalizedString("Cancel", bundle: Bundle.audiobookToolkit()!, value: "Cancel", comment: "Cancel")
        actionSheet.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        actionSheet.popoverPresentationController?.barButtonItem = self.toolbar.items?[self.sleepTimerBarButtonIndex]
        actionSheet.popoverPresentationController?.sourceView = self.view
        self.present(actionSheet, animated: true, completion: nil)
    }

    @objc func coverArtWasPressed(_ sender: Any) { }
    
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
        view.tintColor = self.view.tintColor
        let buttonItem = UIBarButtonItem(customView: view)
        buttonItem.isAccessibilityElement = true
        buttonItem.accessibilityLabel = NSLocalizedString("Airplay", bundle: Bundle.audiobookToolkit()!, value: "Airplay", comment: "Airplay")
        buttonItem.accessibilityHint = NSLocalizedString("Send audio to another airplay-compatible device.", bundle: Bundle.audiobookToolkit()!, value: "Send audio to another airplay-compatible device.", comment: "Longer description to identify airplay button.")
        buttonItem.accessibilityTraits = UIAccessibilityTraitButton
        return buttonItem
    }
    
    func updateUI() {
        if let chapter = self.currentChapter {
            if !self.seekBar.scrubbing && !self.waitingForPlayer {
                let timeLeftInBook = self.timeLeftAfter(chapter: chapter)
                self.seekBar.setOffset(
                    chapter.playheadOffset,
                    duration: chapter.duration,
                    timeLeftInBook: timeLeftInBook,
                    middleText: self.middleTextFor(chapter: chapter)
                )
                if let barButtonItem = self.toolbar.items?[self.sleepTimerBarButtonIndex] {
                    let texts = self.textsFor(sleepTimer: self.audiobookManager.sleepTimer, chapter: chapter)
                    barButtonItem.title = texts.title
                    barButtonItem.accessibilityLabel = texts.accessibilityLabel
                }
                if self.waitingToTogglePlayPause {
                    if self.audiobookManager.audiobook.player.isPlaying {
                        self.playbackControlView.showPauseButtonIfNeeded()
                    } else {
                        self.playbackControlView.showPlayButtonIfNeeded()
                    }
                    self.waitingToTogglePlayPause = false
                }
            }
        }
    }
    
    func textsFor(sleepTimer: SleepTimer, chapter: ChapterLocation) -> (title: String, accessibilityLabel: String) {
        let title: String
        let accessibilityLabel: String
        if sleepTimer.isActive {
            title = HumanReadableTimestamp(timeInterval: sleepTimer.timeRemaining).value
            let voiceOverTimeRemaining = VoiceOverTimestamp(
                timeInterval: sleepTimer.timeRemaining
            ).value
            let middleTextFormat = NSLocalizedString("%@ until playback pauses", bundle: Bundle.audiobookToolkit()!, value: "%@ until playback pauses", comment: "localized time until playback pauses, for voice over")
            accessibilityLabel = String(format: middleTextFormat, voiceOverTimeRemaining)
        } else {
            title = self.sleepTimerDefaultText
            accessibilityLabel = self.sleepTimerDefaultAccessibilityLabel
        }
        return (title: title, accessibilityLabel: accessibilityLabel)
    }

    func middleTextFor(chapter: ChapterLocation) -> String {
        let middleTextFormat = NSLocalizedString("Chapter %d of %d", bundle: Bundle.audiobookToolkit()!, value: "Chapter %d of %d", comment: "Current chapter and the amount of chapters left in the book")
        return String(format: middleTextFormat, chapter.number, self.audiobookManager.audiobook.spine.count)
    }

    func playbackSpeedTextFor(speedText: String) -> String {
        let speedAccessibilityFormatString = NSLocalizedString("Playback speed %@", bundle: Bundle.audiobookToolkit()!, value: "Playback speed %@", comment: "Playback speed with localized format, used for voice over")
        return String(format: speedAccessibilityFormatString, speedText)
    }
}

extension AudiobookPlayerViewController: AudiobookManagerTimerDelegate {
    public func audiobookManager(_ audiobookManager: AudiobookManager, didUpdate timer: Timer?) {
        self.updateUI()
    }
}

extension AudiobookPlayerViewController: PlaybackControlViewDelegate {
    func playbackControlViewSkipBackButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.audiobookManager.audiobook.player.skipBack()
        self.waitingForPlayer = false
        self.updateUI()
    }
    
    func playbackControlViewSkipForwardButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.audiobookManager.audiobook.player.skipForward()
        self.waitingForPlayer = false
        self.updateUI()
    }

    func playbackControlViewPlayButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.activityIndicator.startAnimating()
        self.playbackControlView.togglePlayPauseButtonUIState()
        if self.audiobookManager.audiobook.player.isPlaying {
            self.audiobookManager.audiobook.player.pause()
        } else {
            self.audiobookManager.audiobook.player.play()
        }
        self.updateUI()
    }
}

extension AudiobookPlayerViewController: PlayerDelegate {
    // It may seem like we want to update the UI in these delegates, but we do not.
    // Sometimes the FindawayPlayer sends
    // `didBeginPlaybackOf`, `didStopPlaybackOf`,  `didComplete` before the player
    // has actually updated it's currentOffset. If the user has scrubbed the
    // seek bar to a new playhead, and then we update on `didBeginPlaybackOf`,
    // our playhead might momenterally flash at the old playhead.
    //
    // This a known bug in the AudioEngine player. It has been reported
    // to them and will hopefully be fixed.

    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.waitingForPlayer = false
        self.activityIndicator.stopAnimating()
        self.updatePlayPauseButtonIfNeeded()
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.waitingForPlayer = false
        self.activityIndicator.stopAnimating()
        self.updatePlayPauseButtonIfNeeded()
    }

    public func player(_ player: Player, didComplete chapter: ChapterLocation) {
        self.waitingForPlayer = false
        self.activityIndicator.stopAnimating()
        self.updatePlayPauseButtonIfNeeded()
    }

    private func updatePlayPauseButtonIfNeeded() {
        if self.audiobookManager.audiobook.player.isPlaying {
            self.playbackControlView.showPauseButtonIfNeeded()
        } else {
            self.playbackControlView.showPlayButtonIfNeeded()
        }
    }
}

extension AudiobookPlayerViewController: AudiobookNetworkServiceDelegate {
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) {}
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement) {}
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement) {}
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError, for spineElement: SpineElement) {
        let errorLocalizedText = NSLocalizedString("Error!", bundle: Bundle.audiobookToolkit()!, value: "Error!", comment: "Error!")
        let alertController = UIAlertController(
            title: errorLocalizedText,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        let okLocalizedText = NSLocalizedString("Ok", bundle: Bundle.audiobookToolkit()!, value: "Ok", comment: "Ok")
        alertController.addAction(UIAlertAction(title: okLocalizedText, style: .cancel, handler: nil))
        alertController.popoverPresentationController?.sourceView = self.view
        self.present(alertController, animated: true, completion: nil)
    }
}

extension AudiobookPlayerViewController: ScrubberViewDelegate {
    func scrubberView(_ scrubberView: ScrubberView, didRequestScrubTo offset: TimeInterval) {
        if let chapter = self.currentChapter?.chapterWith(offset) {
            if self.audiobookManager.audiobook.player.isPlaying {
                self.audiobookManager.audiobook.player.playAtLocation(chapter)
            } else {
                self.audiobookManager.audiobook.player.movePlayheadToLocation(chapter)
            }
        }
        self.waitingForPlayer = true
        self.updateUI()
    }

    func scrubberViewDidRequestAccessibilityIncrement(_ scrubberView: ScrubberView) {
        self.audiobookManager.audiobook.player.skipForward()
    }

    func scrubberViewDidRequestAccessibilityDecrement(_ scrubberView: ScrubberView) {
        self.audiobookManager.audiobook.player.skipBack()
    }
}

