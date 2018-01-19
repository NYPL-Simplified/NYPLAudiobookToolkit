//
//  AudiobookViewController.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/11/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout
import MediaPlayer

public class AudiobookViewController: UIViewController {

    private var seekBar = Scrubber()
    private var coverView: UIImageView = { () -> UIImageView in
        let imageView = UIImageView()
        imageView.image = UIImage(named: "exampleCover", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        imageView.accessibilityIdentifier = "cover_art"
        return imageView
    }()

    private var skipBackView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_back", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        view.text = "15"
        view.accessibilityIdentifier = "skip_back"
        return view
    }()

    private var skipForwardView: TextOverImageView = { () -> TextOverImageView in
        let view = TextOverImageView()
        view.image = UIImage(named: "skip_forward", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        view.text = "15"
        view.accessibilityIdentifier = "skip_forward"
        return view
    }()

    private var playButton: UIImageView = { () -> UIImageView in
        let imageView = UIImageView()
        imageView.image = UIImage(named: "play", in: Bundle(identifier: "NYPLAudiobooksToolkit.NYPLAudiobookToolkit"), compatibleWith: nil)
        imageView.accessibilityIdentifier = "play_button"
        return imageView
    }()
    
    private var audioRouteButton: MPVolumeView = { () -> MPVolumeView in
        let view = MPVolumeView()
        view.showsVolumeSlider = false
        view.sizeToFit()
        return view
    }()

    let audiobookMetadata = AudiobookMetadata(
        title: "Les Trois Mousquetaires",
        authors: ["Alexandre Dumas"],
        narrators: ["John Hodgeman"],
        publishers: ["LibriVox"],
        published: Date(),
        modified: Date(),
        language: "en"
    )

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.backBarButtonItem?.title = nil
        let bbi = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(AudiobookViewController.tocWasPressed))
        self.navigationItem.rightBarButtonItem = bbi
        self.navigationItem.title = self.audiobookMetadata.title
        self.view.backgroundColor = UIColor.white
        
        self.view.addSubview(self.coverView)
        self.coverView.autoPin(toTopLayoutGuideOf: self, withInset: 16)
        self.coverView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.autoSetDimensions(to: CGSize(width: 300, height: 300))
        
        self.view.addSubview(self.seekBar)
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: 16)
        self.seekBar.autoPinEdge(.left, to: .left, of: self.view, withOffset: 8)
        self.seekBar.autoPinEdge(.right, to: .right, of: self.view, withOffset: -8)

        self.view.addSubview(self.playButton)
        self.playButton.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.playButton.autoPinEdge(.top, to: .bottom, of: self.seekBar, withOffset: 16)
        self.playButton.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(AudiobookViewController.playButtonWasTapped(_:))
            )
        )
        self.playButton.isUserInteractionEnabled = true

        self.view.addSubview(self.skipBackView)
        self.skipBackView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipBackView.autoPinEdge(.right, to: .left, of: self.playButton, withOffset: -16)
        self.skipBackView.autoPinEdge(.left, to: .left, of: self.view, withOffset: 0, relation: .greaterThanOrEqual)
        self.skipBackView.autoSetDimensions(to: CGSize(width: 66, height: 66))

        self.view.addSubview(self.skipForwardView)
        self.skipForwardView.autoAlignAxis(.horizontal, toSameAxisOf: self.playButton)
        self.skipForwardView.autoPinEdge(.left, to: .right, of: self.playButton, withOffset: 16)
        self.skipForwardView.autoPinEdge(.right, to: .right, of: self.view, withOffset: 0, relation: .lessThanOrEqual)
        self.skipForwardView.autoSetDimensions(to: CGSize(width: 66, height: 66))

        
        self.view.backgroundColor = UIColor.groupTableViewBackground
        let airplayView = UIView()
        self.view.addSubview(airplayView)
        airplayView.autoSetDimensions(to: CGSize(width: 30, height: 30))
        airplayView.autoAlignAxis(.vertical, toSameAxisOf: self.playButton)
        airplayView.autoPinEdge(.top, to: .bottom, of: self.playButton, withOffset: 8)
        airplayView.autoPinEdge(.left, to: .left, of: self.view, withOffset: 0, relation: .greaterThanOrEqual)
        airplayView.autoPinEdge(.right, to: .right, of: self.view, withOffset: 0, relation: .lessThanOrEqual)
        let mpv = MPVolumeView(frame: airplayView.bounds)
        mpv.showsVolumeSlider = false
        mpv.showsRouteButton = true
        mpv.translatesAutoresizingMaskIntoConstraints = false
        airplayView.addSubview(mpv)
        mpv.autoPinEdgesToSuperviewEdges()
        mpv.sizeToFit()

        self.seekBar.play()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @objc public func playButtonWasTapped(_ sender: Any) {
        self.seekBar.toggle()
    }

    @objc public func tocWasPressed(_ sender: Any) {
        let tbvc = UITableViewController()
        tbvc.tableView.dataSource = self
        tbvc.navigationItem.title = "Table Of Contents"
        self.navigationController?.pushViewController(tbvc, animated: true)
    }
}

extension AudiobookViewController: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = "Chapter \(indexPath.row)"
        return cell
    }
}
