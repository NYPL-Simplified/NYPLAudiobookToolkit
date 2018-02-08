//
//  AudiobookViewController.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/11/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import Foundation
import AudioEngine
import PureLayout

public let GrayBackgroundColor = UIColor(red: 219/255, green: 220/255, blue: 223/255, alpha: 1)

public class AudiobookDetailViewController: UIViewController {
    
    private let audiobookManager: AudiobookManager
    private var currentChapter: ChapterDescription?

    public required init(audiobookManager: AudiobookManager) {
        self.audiobookManager = audiobookManager
        super.init(nibName: nil, bundle: nil)
        self.audiobookManager.downloadDelegate = self
        self.audiobookManager.playbackDelegate = self
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let padding = CGFloat(8)
    private let seekBar = ScrubberView()
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
    private let chapterTitleLabel: UILabel = { () -> UILabel in
        let theLabel = UILabel()
        theLabel.numberOfLines = 1
        theLabel.textAlignment = NSTextAlignment.center
        theLabel.font = UIFont.systemFont(ofSize: 18)
        theLabel.text = ""
        theLabel.accessibilityIdentifier = "chapter_label"
        return theLabel
    }()

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.backIndicatorImage = UIImage()
        self.navigationController?.navigationBar.barTintColor = GrayBackgroundColor
        self.navigationController?.navigationBar.isTranslucent = false
        self.view.backgroundColor = GrayBackgroundColor
        self.playbackControlView.backgroundColor = GrayBackgroundColor
        self.navigationItem.backBarButtonItem?.title = self.audiobookManager.metadata.title
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
    
        self.view.addSubview(self.coverView)
        self.coverView.autoPin(toTopLayoutGuideOf: self, withInset: self.padding)
        self.coverView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.autoSetDimensions(to: CGSize(width: 266, height: 266))
        
        self.view.addSubview(self.seekBar)
        self.seekBar.delegate = self;
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: self.padding)
        self.seekBar.autoPinEdge(.left, to: .left, of: self.coverView)
        self.seekBar.autoPinEdge(.right, to: .right, of: self.coverView)

        self.view.addSubview(self.chapterTitleLabel)
        NSLayoutConstraint.autoSetPriority(.defaultLow) {
            self.chapterTitleLabel.autoSetDimension(.height, toSize: 0, relation: .equal)
        }
        self.chapterTitleLabel.autoPinEdge(.top, to: .bottom, of: seekBar, withOffset: self.padding)
        self.chapterTitleLabel.autoPinEdge(.left, to: .left, of: self.view, withOffset: self.padding)
        self.chapterTitleLabel.autoPinEdge(.right, to: .right, of: self.view, withOffset: -self.padding)

        self.view.addSubview(self.playbackControlView)
        self.playbackControlView.delegate = self
        self.playbackControlView.autoPinEdge(.top, to: .bottom, of: self.chapterTitleLabel, withOffset: self.padding)
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
        
        self.coverView.addGestureRecognizer(
            UILongPressGestureRecognizer(
                target: self,
                action: #selector(AudiobookDetailViewController.coverArtWasLongPressed(_:))
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
        let tbvc = UITableViewController()
        tbvc.tableView.dataSource = self
        tbvc.navigationItem.title = "Table Of Contents"
        self.navigationController?.pushViewController(tbvc, animated: true)
    }

    @objc func coverArtWasPressed(_ sender: Any) {
        self.audiobookManager.fetch()
    }

    /// DELETE THIS coverArtWasLongPressed OR UPDATE IT TO USE MANAGER
    @objc public func coverArtWasLongPressed(_ sender: Any) {
        let alertController = UIAlertController(title: "Delete", message: "Delete cached audiobook.", preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { (action) in
            FAEAudioEngine.shared()?.downloadEngine?.deleteAll()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
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
    public func audiobookManagerReadyForPlayback(_ audiobookManager: AudiobookManager) {
        self.chapterTitleLabel.text = "Title Downloaded!"
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { (timer) in
            self.navigationItem.title = nil
            self.navigationItem.backBarButtonItem?.title = self.audiobookManager.metadata.title
            if self.chapterTitleLabel.text == "Title Downloaded!"  {
                if let chapter = self.currentChapter {
                    self.chapterTitleLabel.text = "Chapter \(chapter.number)"
                } else {
                    self.chapterTitleLabel.text = ""
                }
            }
        }
    }
    
    // TODO: have more defined relationships for how errors come in and will be handled
    public func audiobookManager(_ audiobookManager: AudiobookManager, didReceive error: AudiobookError) {
        let errorMessage = ((error.error as? NSError)?.userInfo["localizedMessage"] as? String ?? "Something is rotten in the state of Denmark.")
        self.present(UIAlertController(title: "Error!", message: errorMessage, preferredStyle: .alert), animated: false, completion: nil)
    }
    
    public func audiobookManager(_ audiobookManager: AudiobookManager, didUpdateDownloadPercentage percentage: Float) {
        self.chapterTitleLabel.text = "Downloading \(Int(percentage * 100))%"
    }
}

extension AudiobookDetailViewController: AudiobookManagerPlaybackDelegate {
    public func audiobookManager(_ audiobookManager: AudiobookManager, didBeginPlaybackOf chapter: ChapterDescription) {
        self.updateUIWithChapter(chapter, scrubbing: true)
    }

    public func audiobookManager(_ audiobookManager: AudiobookManager, didStopPlaybackOf chapter: ChapterDescription) {
        self.updateUIWithChapter(chapter, scrubbing: false)
    }
    
    func updateUIWithChapter(_ chapter: ChapterDescription, scrubbing: Bool) {
        self.currentChapter = chapter
        self.chapterTitleLabel.text = "Chapter \(chapter.number)"
        self.seekBar.setOffset(chapter.offset, duration: chapter.duration)
        if scrubbing {
            self.updateControlsForPlaybackStart()
        } else {
            self.updateControlsForPlaybackStop()
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

    func scrubberViewDidBeginScrubbing(_ scrubberView: ScrubberView) {
        self.audiobookManager.pause()
    }
}

extension AudiobookDetailViewController: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = "Chapter \(indexPath.row)"
        return cell
    }
}
