import UIKit
import Foundation
import PureLayout
import AVKit
import MediaPlayer
import NYPLUtilitiesObjc

let SkipTimeInterval: Double = 15
private let bookmarkOnImageName = "BookmarkOn"
private let bookmarkOffImageName = "BookmarkOff"
private let tocImageName = "table_of_contents"

@objcMembers public final class AudiobookPlayerViewController: UIViewController {

    private let audiobookManager: AudiobookManager
    public var currentChapterLocation: ChapterLocation? {
        return self.audiobookManager.audiobook.player.currentChapterLocation
    }

    public required init(audiobookManager: AudiobookManager) {
        self.audiobookManager = audiobookManager
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
    private var bookmarkBarButton: UIBarButtonItem?
    private var bookmarkButtonOn: Bool = false
    private let bookmarkButtonStateLock = NSRecursiveLock()

    private let activityIndicator = BufferActivityIndicatorView()
    private let gradient = CAGradientLayer()
    private let padding = CGFloat(12)

    private let toolbar = UIToolbar()
    private let toolbarHeight: CGFloat = 44
    private let toolbarButtonWidth: CGFloat = 100.0

    private let audioRouteButtonWidth: CGFloat = 50.0
    private let audioRoutingBarButtonIndex = 3
    private let speedBarButtonIndex = 1
    private let sleepTimerBarButtonIndex = 5
    private let sleepTimerDefaultText = "☾"
    private let sleepTimerDefaultAccessibilityLabel = NSLocalizedString("Sleep Timer", bundle: Bundle.audiobookToolkit()!, value: "Sleep Timer", comment:"Sleep Timer")

    private var audiobookProgressView = DownloadProgressView()
    private var progressViewBackgroundColor: UIColor {
        if #available(iOS 12.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            return NYPLColor.secondaryBackgroundColor
        } else {
            return view.tintColor
        }
    }
    
    private let chapterInfoStack = ChapterInfoStack()
    public var coverView: AudiobookCoverImageView = { () -> AudiobookCoverImageView in
        let image = UIImage(named: "example_cover", in: Bundle.audiobookToolkit(), compatibleWith: nil)
        let imageView = AudiobookCoverImageView.init(image: image)
        return imageView
    }()
    private let seekBar: ScrubberView = ScrubberView()
    private let playbackControlView = PlaybackControlView()

    private var waitingForPlayer = false {
        didSet {
            if !waitingForPlayer {
                self.activityIndicator.stopAnimating()
            }
        }
    }
    private var shouldBeginToAutoPlay = false

    private var compactWidthConstraints: [NSLayoutConstraint]!
    private var regularWidthConstraints: [NSLayoutConstraint]!

    //MARK:-

    deinit {
        ATLog(.debug, "AudiobookPlayerViewController has deinitialized.")
        self.audiobookManager.audiobook.player.unload()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        playbackControlView.delegate = self
        seekBar.delegate = self

        setupUI()
        enableConstraints() // iOS < 13 used to guarantee `traitCollectionDidChange` was called, but not anymore
        updateColors()
      
        if let bizLogic = audiobookManager.bookmarkBusinessLogic,
            bizLogic.shouldAllowRefresh {
          bizLogic.syncBookmarks { _ in }
        }
    }
  
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.gradient.frame = self.view.bounds
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.audiobookManager.timerDelegate = self

        if self.audiobookManager.audiobook.player.isPlaying {
            self.playbackControlView.showPauseButtonIfNeeded()
            self.waitingForPlayer = false
        } else if self.shouldBeginToAutoPlay {
            self.audiobookManager.audiobook.player.play()
            self.shouldBeginToAutoPlay = false
        }

        self.updateSpeedButtonIfNeeded()
        self.updateUI()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.audiobookManager.timerDelegate = nil
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        enableConstraints()
        if #available(iOS 12.0, *),
           previousTraitCollection?.userInterfaceStyle != UIScreen.main.traitCollection.userInterfaceStyle {
            updateColors()
        }
    }

    //MARK:-

    func enableConstraints() {
        if traitCollection.horizontalSizeClass == .regular {
            if compactWidthConstraints.count > 0 && compactWidthConstraints[0].isActive {
                NSLayoutConstraint.deactivate(compactWidthConstraints)
            }
            NSLayoutConstraint.activate(regularWidthConstraints)
        } else {
            if regularWidthConstraints.count > 0 && regularWidthConstraints[0].isActive {
                NSLayoutConstraint.deactivate(regularWidthConstraints)
            }
            NSLayoutConstraint.activate(compactWidthConstraints)
        }
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

            if element.chapter.inSameChapter(other: self.currentChapterLocation) {
                newResult = timeLeftInChapter
                addUpStuff = true
            }
            return newResult
        })
        return timeLeftAfterChapter
    }
  
    @objc func bookmarkWasPressed() {
      guard let chapterLocation = currentChapterLocation,
            let businessLogic = audiobookManager.bookmarkBusinessLogic else {
        return
      }
      
      bookmarkButtonStateLock.lock()
      defer {
        bookmarkButtonStateLock.unlock()
      }
      
      if bookmarkButtonOn,
         let bookmark = businessLogic.bookmarkExisting(at: chapterLocation) {
        businessLogic.deleteAudiobookBookmark(bookmark)
      } else {
        businessLogic.addAudiobookBookmark(chapterLocation)
      }
      updateBookmarkButton(withState: !bookmarkButtonOn)
    }

    @objc public func tocWasPressed(_ sender: Any) {
      let readerPositionVC = AudiobookReaderPositionsVC(
        bookmarksBusinessLogic: audiobookManager.bookmarkBusinessLogic,
        tocProvider: audiobookManager.tableOfContents)
      readerPositionVC.selectionDelegate = self
      self.navigationController?.pushViewController(readerPositionVC, animated: true)
    }
    
    @objc public func speedWasPressed(_ sender: Any) {
        func actionFrom(rate: PlaybackRate, player: Player) -> UIAlertAction {
            let handler = { (_ action: UIAlertAction) -> Void in
                player.playbackRate = rate
                self.updateSpeedButtonIfNeeded(rate: rate)
            }
            let title = HumanReadablePlaybackRate(rate: rate).value
            let action = UIAlertAction(title: title, style: .default, handler: handler)
            action.accessibilityLabel = HumanReadablePlaybackRate(rate: rate).accessibleDescription
            return action
        }
        
        let actionSheetTitle = NSLocalizedString("Playback Speed", bundle: Bundle.audiobookToolkit()!, value: "Playback Speed", comment: "Title to set how fast the audio plays")

        let actionSheet: UIAlertController
        if self.traitCollection.horizontalSizeClass == .regular && UIAccessibility.isVoiceOverRunning {
            actionSheet = UIAlertController(title: actionSheetTitle, message: nil, preferredStyle: .alert)
        } else {
            actionSheet = UIAlertController(title: actionSheetTitle, message: nil, preferredStyle: .actionSheet)
        }

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

    private func updateSleepTimerIfNeeded() {
        if let barButtonItem = self.toolbar.items?[self.sleepTimerBarButtonIndex],
        let chapter = self.currentChapterLocation {
            let texts = self.sleepTimerText(forSleepTimer: self.audiobookManager.sleepTimer, chapter: chapter)
            barButtonItem.width = toolbarButtonWidth
            barButtonItem.title = texts.title
            barButtonItem.accessibilityLabel = texts.accessibilityLabel
        }
    }

    private func updateSpeedButtonIfNeeded(rate: PlaybackRate? = nil) {
        let rate = rate ?? self.audiobookManager.audiobook.player.playbackRate
        var buttonTitle = HumanReadablePlaybackRate(rate: rate).value
        guard let buttonItem = self.toolbar.items?[self.speedBarButtonIndex],
        buttonItem.title != buttonTitle else {
            return
        }

        if rate == .normalTime {
            buttonTitle = NSLocalizedString("1.0×",
                                            bundle: Bundle.audiobookToolkit()!,
                                            value: "1.0×",
                                            comment: "Default title to explain that button changes the speed of playback.")
        }
        buttonItem.width = toolbarButtonWidth
        buttonItem.title = buttonTitle
        buttonItem.accessibilityLabel = HumanReadablePlaybackRate(rate: rate).accessibleDescription
    }
  
    private func updateBookmarkButton(withState isOn: Bool) {
      bookmarkButtonStateLock.lock()
      defer {
        bookmarkButtonStateLock.unlock()
      }
      
      guard let btn = bookmarkBarButton,
            bookmarkButtonOn != isOn else {
        return
      }
      
      bookmarkButtonOn = isOn

      if bookmarkButtonOn {
        btn.image = UIImage(named: bookmarkOnImageName)
        btn.accessibilityLabel = NSLocalizedString("Remove Bookmark",
                                                   comment: "Accessibility label for button to remove a bookmark")
      } else {
        btn.image = UIImage(named: bookmarkOffImageName)
        btn.accessibilityLabel = NSLocalizedString("Add Bookmark",
                                                   comment: "Accessibility label for button to add a bookmark")
      }
    }

    @objc public func sleepTimerWasPressed(_ sender: Any) {
        func actionFrom(trigger: SleepTimerTriggerAt, sleepTimer: SleepTimer) -> UIAlertAction {
            let handler = { (_ action: UIAlertAction) -> Void in
                sleepTimer.setTimerTo(trigger: trigger)
                self.updateSleepTimerIfNeeded()
            }
            var action: UIAlertAction! = nil
            switch trigger {
            case .endOfChapter:
                let title = NSLocalizedString("End of Chapter", bundle: Bundle.audiobookToolkit()!, value: "End of Chapter", comment: "End of Chapter")
                action = UIAlertAction(title: title, style: .default, handler: handler)
            case .oneHour:
                let title = NSLocalizedString("60 Minutes", bundle: Bundle.audiobookToolkit()!, value: "60 Minutes", comment: "60 Minutes")
                action = UIAlertAction(title: title, style: .default, handler: handler)
            case .thirtyMinutes:
                let title = NSLocalizedString("30 Minutes", bundle: Bundle.audiobookToolkit()!, value: "30 Minutes", comment: "30 Minutes")
                action = UIAlertAction(title: title, style: .default, handler: handler)
            case .fifteenMinutes:
                let title = NSLocalizedString("15 Minutes", bundle: Bundle.audiobookToolkit()!, value: "15 Minutes", comment: "15 Minutes")
                action = UIAlertAction(title: title, style: .default, handler: handler)
            case .never:
                let title = NSLocalizedString("Off", bundle: Bundle.audiobookToolkit()!, value: "Off", comment: "Off")
                action = UIAlertAction(title: title, style: .default, handler: handler)
            }
            return action
        }
        let title = NSLocalizedString("Sleep Timer", bundle: Bundle.audiobookToolkit()!, value: "Sleep Timer", comment: "Sleep Timer")

        let actionSheet: UIAlertController
        if self.traitCollection.horizontalSizeClass == .regular && UIAccessibility.isVoiceOverRunning {
            actionSheet = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        } else {
            actionSheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        }

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

    func audioRoutingBarButtonItem() -> UIBarButtonItem {
        let view: UIView
        if #available(iOS 11.0, *) {
            view = AVRoutePickerView()
        } else {
            let volumeView = MPVolumeView()
            volumeView.showsVolumeSlider = false
            volumeView.showsRouteButton = true
            // Set tint of route button: https://stackoverflow.com/a/33016391
            for view in volumeView.subviews {
                if view.isKind(of: UIButton.self) {
                    let buttonOnVolumeView = view as! UIButton
                    volumeView.setRouteButtonImage(buttonOnVolumeView.currentImage?.withRenderingMode(.alwaysTemplate), for: .normal)
                    break
                }
            }
            volumeView.sizeToFit()
            view = volumeView
        }
        let buttonItem = UIBarButtonItem(customView: view)
        buttonItem.width = audioRouteButtonWidth
        buttonItem.isAccessibilityElement = true
        buttonItem.accessibilityLabel = NSLocalizedString("Playback Destination", bundle: Bundle.audiobookToolkit()!, value: "Playback Destination", comment: "Describe where the sound can be sent. Example: Bluetooth Speakers.")
        buttonItem.accessibilityHint = NSLocalizedString("If another device is available, send the audio over Bluetooth or Airplay. Otherwise do nothing.", bundle: Bundle.audiobookToolkit()!, value: "If another device is available, send the audio over Bluetooth or Airplay. Otherwise do nothing.", comment: "Longer description to describe action of the button.")
        buttonItem.accessibilityTraits = UIAccessibilityTraits.button
        return buttonItem
    }
  
    func setupUI() {
      setupNavBar()
      setupToolbar()
      
      activityIndicator.color = NYPLColor.disabledFieldTextColor
      audiobookManager.audiobook.player.registerDelegate(self)
      audiobookManager.networkService.registerDelegate(self)

      gradient.frame = view.bounds
      gradient.startPoint = CGPoint.zero
      gradient.endPoint = CGPoint(x: 1, y: 1)
      view.layer.insertSublayer(gradient, at: 0)

      view.addSubview(audiobookProgressView)
      audiobookProgressView.backgroundColor = progressViewBackgroundColor
      audiobookProgressView.autoPinEdge(toSuperviewSafeArea: .top)
      audiobookProgressView.autoPinEdge(toSuperviewEdge: .leading)
      audiobookProgressView.autoPinEdge(toSuperviewEdge: .trailing)

      chapterInfoStack.titleText = audiobookManager.metadata.title ?? "Audiobook"
      chapterInfoStack.authors = audiobookManager.metadata.authors ?? [""]

      view.addSubview(chapterInfoStack)
      chapterInfoStack.autoSetDimension(.width, toSize: 500, relation: .lessThanOrEqual)
      chapterInfoStack.autoAlignAxis(toSuperviewAxis: .vertical)
      chapterInfoStack.autoPinEdge(toSuperviewMargin: .leading, relation: .greaterThanOrEqual)
      chapterInfoStack.autoPinEdge(toSuperviewMargin: .trailing, relation: .greaterThanOrEqual)

      view.addSubview(coverView)

      coverView.autoPinEdge(toSuperviewMargin: .leading, relation: .greaterThanOrEqual)
      coverView.autoPinEdge(toSuperviewMargin: .trailing, relation: .greaterThanOrEqual)

      let playbackControlViewContainer = setupPlaybackControlViewContainer()
      
      setupSeekBar()
      
      NSLayoutConstraint.autoSetPriority(.defaultHigh) {
        coverView.autoMatch(.width, to: .height, of: coverView, withMultiplier: 1)
        chapterInfoStack.autoSetDimension(.height, toSize: 50)
        playbackControlViewContainer.autoSetDimension(.height, toSize: 100.0)
        seekBar.autoSetDimension(.width, toSize: 500)
        seekBar.autoPinEdge(.top, to: .bottom, of: chapterInfoStack, withOffset: padding * 6)
      }

      compactWidthConstraints = NSLayoutConstraint.autoCreateConstraintsWithoutInstalling {
        coverView.autoAlignAxis(toSuperviewAxis: .vertical)
        chapterInfoStack.autoPinEdge(.top, to: .bottom, of: audiobookProgressView, withOffset: padding)
        chapterInfoStack.autoSetDimension(.height, toSize: 60.0, relation: .lessThanOrEqual)
      }

      regularWidthConstraints = NSLayoutConstraint.autoCreateConstraintsWithoutInstalling {
        coverView.autoCenterInSuperview()
        coverView.autoSetDimension(.width, toSize: 500.0)
        chapterInfoStack.autoPinEdge(.top, to: .bottom, of: audiobookProgressView, withOffset: padding, relation: .greaterThanOrEqual)
      }
    }
  
    func setupNavBar() {
      var items: [UIBarButtonItem] = []
      
      let tocImage = UIImage(
        named: tocImageName,
        in: Bundle.audiobookToolkit(),
        compatibleWith: nil
      )
      
      let tocBbi = UIBarButtonItem(
        image: tocImage,
        style: .plain,
        target: self,
        action: #selector(tocWasPressed)
      )
      tocBbi.accessibilityLabel = NSLocalizedString("Table of Contents",
                                                    bundle: Bundle.audiobookToolkit()!,
                                                    value: "Table of Contents",
                                                    comment: "Title to describe the list of chapters or tracks.")
      tocBbi.accessibilityHint = NSLocalizedString("Select a chapter or track from a list.",
                                                   bundle: Bundle.audiobookToolkit()!,
                                                   value: "Select a chapter or track from a list.",
                                                   comment: "Explain what a table of contents is.")
      items.append(tocBbi)
      
      let bookmarkImage = UIImage(
        named: bookmarkOffImageName,
        in: Bundle.audiobookToolkit(),
        compatibleWith: nil
      )
    
      let bookmarkBtn = UIBarButtonItem(
        image: bookmarkImage,
        style: .plain,
        target: self,
        action: #selector(bookmarkWasPressed)
      )
      bookmarkBarButton = bookmarkBtn
      updateBookmarkButton(withState: false)
      items.append(bookmarkBtn)
      
      activityIndicator.hidesWhenStopped = true
      let indicatorBbi = UIBarButtonItem(customView: activityIndicator)
      items.append(indicatorBbi)
      
      navigationItem.rightBarButtonItems = items
    }
  
    func setupSeekBar() {
      let seekBarContainerView = UIView()
      seekBarContainerView.isAccessibilityElement = false
      view.addSubview(seekBarContainerView)

      seekBarContainerView.autoSetDimension(.height, toSize: 100.0)
      seekBarContainerView.autoPinEdge(.top, to: .bottom, of: chapterInfoStack, withOffset: padding)
      seekBarContainerView.autoPinEdge(.bottom, to: .top, of: coverView, withOffset: -padding)
      seekBarContainerView.autoPinEdge(toSuperviewEdge: .leading)
      seekBarContainerView.autoPinEdge(toSuperviewEdge: .trailing)

      seekBarContainerView.addSubview(seekBar)
      seekBar.isUserInteractionEnabled = false
      seekBar.autoCenterInSuperview()
      seekBar.autoPinEdge(toSuperviewEdge: .leading, withInset: padding * 2, relation: .greaterThanOrEqual)
      seekBar.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding * 2, relation: .greaterThanOrEqual)
      
      if let chapter = ChapterLocation(
        number: 0,
        part: 0,
        duration: 4000,
        startOffset: 0,
        playheadOffset: 0,
        title: "test title",
        audiobookID: "12345")
      {
        seekBar.setOffset(
          chapter.playheadOffset,
          duration: chapter.duration,
          timeLeftInBook: timeLeftAfter(chapter: chapter),
          middleText: middleText(forChapter: chapter)
        )
      }
    }
  
    func setupToolbar() {
      let chapter = ChapterLocation(
        number: 0,
        part: 0,
        duration: 4000,
        startOffset: 0,
        playheadOffset: 0,
        title: "test title",
        audiobookID: "12345")!

      view.addSubview(toolbar)
      toolbar.autoPinEdge(toSuperviewSafeArea: .bottom)
      toolbar.autoPinEdge(.left, to: .left, of: view)
      toolbar.autoPinEdge(.right, to: .right, of: view)
      toolbar.autoSetDimension(.height, toSize: toolbarHeight)
      let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
      var items: [UIBarButtonItem] = [flexibleSpace, flexibleSpace, flexibleSpace, flexibleSpace]
      var playbackSpeedText = HumanReadablePlaybackRate(rate: audiobookManager.audiobook.player.playbackRate).value
      if audiobookManager.audiobook.player.playbackRate == .normalTime {
        playbackSpeedText = NSLocalizedString("1.0×",
                                              bundle: Bundle.audiobookToolkit()!,
                                              value: "1.0×",
                                              comment: "Default title to explain that button changes the speed of playback.")
      }
      let speed =  UIBarButtonItem(
        title: playbackSpeedText,
        style: .plain,
        target: self,
        action: #selector(AudiobookPlayerViewController.speedWasPressed(_:))
      )
      speed.width = toolbarButtonWidth
      let playbackButtonName = NSLocalizedString("Playback Speed",
                                                 bundle: Bundle.audiobookToolkit()!,
                                                 value: "Playback Speed",
                                                 comment: "Title to set how fast the audio plays")
      let playbackRateDescription = HumanReadablePlaybackRate(rate: audiobookManager.audiobook.player.playbackRate).accessibleDescription
      speed.accessibilityLabel = "\(playbackButtonName): Currently \(playbackRateDescription)"
      items.insert(speed, at: speedBarButtonIndex)

      let audioRoutingItem = audioRoutingBarButtonItem()
      items.insert(audioRoutingItem, at: audioRoutingBarButtonIndex)
      let texts = sleepTimerText(forSleepTimer: audiobookManager.sleepTimer, chapter: chapter)
      let sleepTimer = UIBarButtonItem(
        title: texts.title,
        style: .plain,
        target: self,
        action: #selector(AudiobookPlayerViewController.sleepTimerWasPressed(_:))
      )
      sleepTimer.width = toolbarButtonWidth
      sleepTimer.accessibilityLabel = texts.accessibilityLabel

      items.insert(sleepTimer, at: sleepTimerBarButtonIndex)
      toolbar.setItems(items, animated: true)
    }
  
    func setupPlaybackControlViewContainer() -> UIView {
      let container = UIView()
      container.addSubview(playbackControlView)
      view.addSubview(container)
      playbackControlView.delegate = self
      playbackControlView.autoCenterInSuperview()
      playbackControlView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0, relation: .greaterThanOrEqual)
      playbackControlView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0, relation: .greaterThanOrEqual)
      playbackControlView.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
      playbackControlView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)

      container.autoSetDimension(.height, toSize: 75, relation: .greaterThanOrEqual)
      container.autoPinEdge(toSuperviewEdge: .left)
      container.autoPinEdge(toSuperviewEdge: .right)
      container.autoPinEdge(.top, to: .bottom, of: coverView, withOffset: padding)
      container.autoPinEdge(.bottom, to: .top, of: toolbar, withOffset: -padding * 2)
      return container
    }
    
    func updateUI() {
        guard let currentLocation = self.currentChapterLocation else {
            return
        }
        if !(self.seekBar.scrubbing || self.waitingForPlayer) {
            let timeLeftInBook = self.timeLeftAfter(chapter: currentLocation)
            self.seekBar.setOffset(
                currentLocation.playheadOffset,
                duration: currentLocation.duration,
                timeLeftInBook: timeLeftInBook,
                middleText: self.middleText(forChapter: currentLocation)
            )
            if let barButtonItem = self.toolbar.items?[self.sleepTimerBarButtonIndex] {
                let texts = self.sleepTimerText(forSleepTimer: self.audiobookManager.sleepTimer, chapter: currentLocation)
                barButtonItem.title = texts.title
                barButtonItem.accessibilityLabel = texts.accessibilityLabel
            }
            self.updateSpeedButtonIfNeeded()
            self.updatePlayPauseButtonIfNeeded()
            if let bookmarkBusinessLogic = audiobookManager.bookmarkBusinessLogic {
              let bookmarkOn = bookmarkBusinessLogic.bookmarkExisting(at: currentLocation) != nil
              updateBookmarkButton(withState: bookmarkOn)
            }
        }
        let color = progressViewBackgroundColor
        if (self.audiobookProgressView.backgroundColor != color) {
            self.audiobookProgressView.backgroundColor = color
        }
    }

    private func updatePlayPauseButtonIfNeeded() {
        if self.audiobookManager.audiobook.player.isPlaying {
            self.playbackControlView.showPauseButtonIfNeeded()
        } else {
            self.playbackControlView.showPlayButtonIfNeeded()
            if activityIndicator.isAnimating {
                activityIndicator.stopAnimating()
            }
        }
    }
    
    private func updateColors() {
        if #available(iOS 12.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            // Set background color to avoid transparent background while presenting
            self.view.backgroundColor = NYPLColor.primaryBackgroundColor
            // Use solid color background for Dark Mode
            self.gradient.colors = [ NYPLColor.primaryBackgroundColor.cgColor ]
        } else {
            let startColor = UIColor(red: (210 / 255), green: (217 / 255), blue: (221 / 255), alpha: 1).cgColor
            self.gradient.colors = [ startColor, UIColor.white.cgColor ]
        }
        self.gradient.setNeedsDisplay()
        
        // Update the tint color of the bottom toolbar to match the tint color of the nav bar
        self.toolbar.tintColor = self.navigationController?.navigationBar.tintColor
    }

    func sleepTimerText(forSleepTimer timer: SleepTimer, chapter: ChapterLocation) -> (title: String, accessibilityLabel: String) {
        let title: String
        let accessibilityLabel: String
        if timer.isActive {
            title = HumanReadableTimestamp(timeInterval: timer.timeRemaining).timecode
            let voiceOverTimeRemaining = VoiceOverTimestamp(
                timeInterval: timer.timeRemaining
            ).value
            let middleTextFormat = NSLocalizedString("%@ until playback pauses", bundle: Bundle.audiobookToolkit()!, value: "%@ until playback pauses", comment: "localized time until playback pauses, for voice over")
            accessibilityLabel = String(format: middleTextFormat, voiceOverTimeRemaining)
        } else {
            title = self.sleepTimerDefaultText
            accessibilityLabel = self.sleepTimerDefaultAccessibilityLabel
        }
        return (title: title, accessibilityLabel: accessibilityLabel)
    }

    func middleText(forChapter chapter: ChapterLocation) -> String {
        let defaultTitleFormat = NSLocalizedString("Chapter %@", bundle: Bundle.audiobookToolkit()!, value: "Chapter %@", comment: "Default chapter title")
        let middleTextFormat = NSLocalizedString("%@ (file %@ of %d)", bundle: Bundle.audiobookToolkit()!, value: "%@ (file %@ of %d)", comment: "Current chapter and the amount of chapters left in the book")
        let indexString = oneBasedSpineIndex() ?? "--"
        let title = chapter.title ?? String(format: defaultTitleFormat, indexString)
        return String(format: middleTextFormat, title, indexString, self.audiobookManager.audiobook.spine.count)
    }

    func playbackSpeedTextFor(speedText: String) -> String {
        let speedAccessibilityFormatString = NSLocalizedString("Playback Speed: %@", bundle: Bundle.audiobookToolkit()!, value: "Playback Speed: %@", comment: "Announce how fast the speaking in the audiobook plays.")
        return String(format: speedAccessibilityFormatString, speedText)
    }

    private func oneBasedSpineIndex() -> String? {
        if let currentChapter = self.currentChapterLocation {
            let spine = self.audiobookManager.audiobook.spine
            for index in 0..<spine.count {
                if currentChapter.inSameChapter(other: spine[index].chapter) {
                    return String(index + 1)
                }
            }
        }
        return nil
    }

    fileprivate func presentAlertAndLog(error: NSError?) {

        let genericTitle = NSLocalizedString("A Problem Has Occurred",
                                             bundle: Bundle.audiobookToolkit()!,
                                             value: "A Problem Has Occurred",
                                             comment: "A Problem Has Occurred")
        var errorTitle = genericTitle
        var errorDescription = "Please try again later."
        if let error = error {
            if error.domain == OpenAccessPlayerErrorDomain {
                if let openAccessPlayerError = OpenAccessPlayerError.init(rawValue: error.code) {
                    errorTitle = openAccessPlayerError.errorTitle()
                    errorDescription = openAccessPlayerError.errorDescription()
                }
            } else if error.domain == OverdrivePlayerErrorDomain {
                if let overdrivePlayerError = OverdrivePlayerError.init(rawValue: error.code) {
                    errorTitle = overdrivePlayerError.errorTitle()
                    errorDescription = overdrivePlayerError.errorDescription()
                }
            } else {
                errorDescription = error.localizedDescription
            }
        }

        let alertController = UIAlertController(title: errorTitle, message: errorDescription, preferredStyle: .alert)
        let okLocalizedText = NSLocalizedString("OK", bundle: Bundle.audiobookToolkit()!, value: "OK", comment: "Okay")

        let alertAction = UIAlertAction(title: okLocalizedText, style: .default) { _ in
            self.waitingForPlayer = false
        }
        alertController.addAction(alertAction)

        self.present(alertController, animated: true)

        let bookID = self.audiobookManager.audiobook.uniqueIdentifier
        let logString = "\(#file): Player reported an error. Audiobook: \(bookID)"
        ATLog(.error, logString, error: error)
    }
}

extension AudiobookPlayerViewController: AudiobookReaderPositionSelectionDelegate {
  func didSelectTOC(_ spineElement: SpineElement) {
    advancePlayer(to: spineElement.chapter)
    self.navigationController?.popViewController(animated: true)
  }
  
  func didSelectBookmark(_ bookmark: NYPLAudiobookBookmark) {
    guard let chapterLocation = ChapterLocation(number: bookmark.chapter,
                                                part: bookmark.part,
                                                duration: bookmark.duration,
                                                startOffset: 0,
                                                playheadOffset: bookmark.time,
                                                title: bookmark.title,
                                                audiobookID: bookmark.audiobookId) else {
      return
    }
    advancePlayer(to: chapterLocation)
    self.navigationController?.popViewController(animated: true)
  }
  
  func advancePlayer(to chapter: ChapterLocation) {
    audiobookManager.audiobook.player.playAtLocation(chapter)
    waitingForPlayer = true
    activityIndicator.startAnimating()

    playbackControlView.showPauseButtonIfNeeded()

    let timeLeftInBook = self.timeLeftAfter(chapter: chapter)
    seekBar.setOffset(
      chapter.playheadOffset,
      duration: chapter.duration,
      timeLeftInBook: timeLeftInBook,
      middleText: self.middleText(forChapter: chapter)
    )

    shouldBeginToAutoPlay = audiobookManager.audiobook.player.isPlaying
  }
}

extension AudiobookPlayerViewController: AudiobookManagerTimerDelegate {
    public func audiobookManager(_ audiobookManager: AudiobookManager, didUpdate timer: Timer?) {
        self.updateUI()
    }
}

extension AudiobookPlayerViewController: PlaybackControlViewDelegate {
    func playbackControlViewSkipBackButtonWasTapped(_ playbackControlView: PlaybackControlView) {

        self.waitingForPlayer = true
        if self.audiobookManager.audiobook.player.isPlaying {
            self.activityIndicator.startAnimating()
        }

        self.audiobookManager.audiobook.player.skipPlayhead(-SkipTimeInterval) { adjustedLocation in
            self.seekBar.setOffset(adjustedLocation.playheadOffset,
                                   duration: adjustedLocation.duration,
                                   timeLeftInBook: self.timeLeftAfter(chapter: adjustedLocation),
                                   middleText: self.middleText(forChapter: adjustedLocation)
            )
        }
    }
    
    func playbackControlViewSkipForwardButtonWasTapped(_ playbackControlView: PlaybackControlView) {

        self.waitingForPlayer = true
        if self.audiobookManager.audiobook.player.isPlaying {
            self.activityIndicator.startAnimating()
        }

        self.audiobookManager.audiobook.player.skipPlayhead(SkipTimeInterval) { adjustedLocation in
            self.seekBar.setOffset(adjustedLocation.playheadOffset,
                                   duration: adjustedLocation.duration,
                                   timeLeftInBook: self.timeLeftAfter(chapter: adjustedLocation),
                                   middleText: self.middleText(forChapter: adjustedLocation)
            )
        }
    }

    func playbackControlViewPlayButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.waitingForPlayer = true
        self.activityIndicator.startAnimating()
        self.audiobookManager.audiobook.player.play()
    }

    func playbackControlViewPauseButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        self.waitingForPlayer = true
        self.activityIndicator.startAnimating()
        self.audiobookManager.audiobook.player.pause()
    }
}

extension AudiobookPlayerViewController: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.waitingForPlayer = false
        self.updatePlayPauseButtonIfNeeded()
        if !self.seekBar.isUserInteractionEnabled {
            self.seekBar.isUserInteractionEnabled = true
        }
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.waitingForPlayer = false
        self.updatePlayPauseButtonIfNeeded()
    }

    public func player(_ player: Player, didFailPlaybackOf chapter: ChapterLocation, withError error: NSError?) {
        presentAlertAndLog(error: error)
    }

    public func player(_ player: Player, didComplete chapter: ChapterLocation) {
        self.waitingForPlayer = false
    }

    public func playerDidUnload(_ player: Player) { }
}

extension AudiobookPlayerViewController: AudiobookNetworkServiceDelegate {
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) {}
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateProgressFor spineElement: SpineElement) {}
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement) {}
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError?, for spineElement: SpineElement) {
        self.presentAlertAndLog(error: error)
        self.audiobookProgressView.stopShowingProgress()
        if let error = error,
          error.domain == OverdrivePlayerErrorDomain && error.code == OverdrivePlayerError.downloadExpired.rawValue {
            self.audiobookManager.refreshDelegate?.audiobookManagerDidRequestRefresh()
        }
    }
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateOverallDownloadProgress progress: Float) {
        if (progress < 1.0) && (self.audiobookProgressView.isHidden) {
            self.audiobookProgressView.beginShowingProgress()
        } else if (Int(progress) == 1) && (!self.audiobookProgressView.isHidden) {
            self.audiobookProgressView.stopShowingProgress()
        }
        self.audiobookProgressView.updateProgress(progress)
    }
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didTimeoutFor spineElement: SpineElement?,
                                        networkStatus: NetworkStatus) {
        DispatchQueue.main.async {
            self.presentAlertAndLog(error: nil)
            self.audiobookProgressView.stopShowingProgress()
        }
    }
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        downloadExceededTimeLimitFor spineElement: SpineElement,
                                        elapsedTime: TimeInterval,
                                        networkStatus: NetworkStatus) {}
}

extension AudiobookPlayerViewController: ScrubberViewDelegate {
    func scrubberView(_ scrubberView: ScrubberView, didRequestScrubTo offset: TimeInterval) {

        guard let requestedOffset = self.currentChapterLocation?.update(playheadOffset: offset),
        let currentOffset = self.currentChapterLocation else {
            ATLog(.error, "Scrubber attempted to scrub without a current chapter.")
            return
        }

        self.waitingForPlayer = true
        if self.audiobookManager.audiobook.player.isPlaying {
            self.activityIndicator.startAnimating()
        }

        let offsetMovement = requestedOffset.playheadOffset - currentOffset.playheadOffset

        self.audiobookManager.audiobook.player.skipPlayhead(offsetMovement) { adjustedLocation in
            self.seekBar.setOffset(adjustedLocation.playheadOffset,
                                   duration: adjustedLocation.duration,
                                   timeLeftInBook: self.timeLeftAfter(chapter: adjustedLocation),
                                   middleText: self.middleText(forChapter: adjustedLocation)
            )
        }
     }

    func scrubberViewDidRequestAccessibilityIncrement(_ scrubberView: ScrubberView) {
        self.audiobookManager.audiobook.player.skipPlayhead(SkipTimeInterval, completion: nil)
    }

    func scrubberViewDidRequestAccessibilityDecrement(_ scrubberView: ScrubberView) {
        self.audiobookManager.audiobook.player.skipPlayhead(-SkipTimeInterval, completion: nil)
    }
}

