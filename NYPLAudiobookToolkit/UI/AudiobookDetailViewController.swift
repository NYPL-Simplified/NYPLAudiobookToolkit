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

public class AudiobookDetailViewController: UIViewController, PlaybackControlViewDelegate, AudiobookManagementDelegate {
    public func audiobookManagerReadyForPlayback(_ AudiobookManagment: AudiobookManagement) {
        self.navigationItem.title = "Title Downloaded!"
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { (timer) in
            self.navigationItem.title = self.audiobookManager.metadata.title
        }
    }

    // TODO: have more defined relationships for how errors come in and will be handled
    public func audiobookManager(_ AudiobookManagment: AudiobookManagement, didRecieve error: AudiobookError) {
        let errorMessage = ((error.error as? NSError)?.userInfo["localizedMessage"] as? String ?? "Oops, something went wrong!")
        self.present(UIAlertController(title: "Error!", message: errorMessage, preferredStyle: .alert), animated: false, completion: nil)
    }

    public func audiobookManager(_ AudiobookManagment: AudiobookManagement, didUpdateDownloadPercentage percentage: Int) {
        self.navigationItem.title = "Downloading \(percentage)%"
    }
    private let audiobookManager: AudiobookManagement

    public required init(audiobookManager: AudiobookManagement) {
        self.audiobookManager = audiobookManager
        super.init(nibName: nil, bundle: nil)
        self.audiobookManager.delegate = self
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let padding = CGFloat(8)
    private let seekBar = ScrubberView()
    private let playbackControlView = PlaybackControlView()
    private let coverView: UIImageView = { () -> UIImageView in
        let imageView = UIImageView()
        imageView.image = UIImage(named: "exampleCover", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        imageView.isUserInteractionEnabled = true
        imageView.accessibilityIdentifier = "cover_art"
        return imageView
    }()

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.backBarButtonItem?.title = nil
        let bbi = UIBarButtonItem(
            barButtonSystemItem: .bookmarks,
            target: self,
            action: #selector(AudiobookDetailViewController.tocWasPressed)
        )
        self.navigationItem.rightBarButtonItem = bbi
        self.navigationItem.title = self.audiobookManager.metadata.title
        self.view.backgroundColor = UIColor.white
        
        self.view.addSubview(self.coverView)
        self.coverView.autoPin(toTopLayoutGuideOf: self, withInset: self.padding)
        self.coverView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.autoSetDimensions(to: CGSize(width: 266, height: 266))
        
        self.view.addSubview(self.seekBar)
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: self.padding)
        self.seekBar.autoPinEdge(.left, to: .left, of: self.view, withOffset: self.padding)
        self.seekBar.autoPinEdge(.right, to: .right, of: self.view, withOffset: -self.padding)

        
        self.view.addSubview(self.playbackControlView)
        self.playbackControlView.delegate = self
        self.playbackControlView.autoPin(toBottomLayoutGuideOf: self, withInset: self.padding)
        self.playbackControlView.autoPinEdge(.top, to: .bottom, of: self.seekBar, withOffset: self.padding, relation: .lessThanOrEqual)
        self.playbackControlView.autoPinEdge(.left, to: .left, of: self.view, withOffset: 0, relation: .greaterThanOrEqual)
        self.playbackControlView.autoPinEdge(.right, to: .right, of: self.view, withOffset: 0, relation: .lessThanOrEqual)
        self.playbackControlView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        
        self.coverView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(AudiobookDetailViewController.coverArtWasPressed(_:))))
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

    func playbackControlViewPlayButtonWasTapped(_ playbackControlView: PlaybackControlView) {
        if self.audiobookManager.isPlaying {
            self.audiobookManager.pause()
            self.seekBar.pause()
        } else {
            self.audiobookManager.play()
            self.seekBar.play()
        }
    }
    
    @objc func coverArtWasPressed(_ sender: Any) {
        self.audiobookManager.fetch()
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
