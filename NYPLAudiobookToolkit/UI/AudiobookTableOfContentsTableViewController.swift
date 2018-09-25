//
//  AudiobookTableOfContentsTableViewController.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

let AudiobookTableOfContentsTableViewControllerCellIdentifier = "AudiobookTableOfContentsTableViewControllerCellIdentifier"

public protocol AudiobookTableOfContentsTableViewControllerDelegate {
    func userSelectedSpineItem(item: SpineElement)
}

public class AudiobookTableOfContentsTableViewController: UITableViewController, AudiobookTableOfContentsDelegate {


    //MARK: - AudiobookTableOfContentsDelegate

    func audiobookTableOfContentsDidRequestReload(_ audiobookTableOfContents: AudiobookTableOfContents) {
        if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.reloadData()
            self.tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .none)
        } else {
            self.tableView.reloadData()
        }
    }

    func audiobookTableOfContentsPendingStatusDidUpdate(inProgress: Bool) {
        if inProgress {
            self.activityIndicator.startAnimating()
        } else {
            self.activityIndicator.stopAnimating()
        }
    }

    func audiobookTableOfContentsUserSelected(spineItem: SpineElement) {
        self.delegate?.userSelectedSpineItem(item: spineItem)
    }

    //MARK: -

    let tableOfContents: AudiobookTableOfContents
    let delegate: AudiobookTableOfContentsTableViewControllerDelegate?
    private let activityIndicator: UIActivityIndicatorView
    public init(tableOfContents: AudiobookTableOfContents, delegate: AudiobookTableOfContentsTableViewControllerDelegate?) {
        self.tableOfContents = tableOfContents
        self.delegate = delegate
        self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        self.activityIndicator.hidesWhenStopped = true
        super.init(nibName: nil, bundle: nil)
        //TODO localize when text is final (or replace with icon)
        let downloadAllItem = UIBarButtonItem(
            title: "(Download All)",
            style: .plain,
            target: self,
            action: #selector(AudiobookTableOfContentsTableViewController.downloadAllChaptersRequested(_:)))
        let activityItem = UIBarButtonItem(
            customView: self.activityIndicator)
        self.navigationItem.rightBarButtonItems = [ downloadAllItem, activityItem ]
        self.tableOfContents.delegate = self
        self.tableView.dataSource = self.tableOfContents
        self.tableView.delegate = self.tableOfContents
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        let container = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: 80))
        self.tableView.tableFooterView = container

        let deleteButton = UIButton()
        container.addSubview(deleteButton)

        let title = NSLocalizedString("Clear Downloads", bundle: Bundle.audiobookToolkit()!, value: "Clear Downloads", comment: "Remove downloaded chapters from the device to save storage space")

        deleteButton.autoCenterInSuperview()
        deleteButton.setTitle(title, for: .normal)
        deleteButton.setTitleColor(.red, for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteChapterRequested(_:)), for: .touchUpInside)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let currentPlayingChapter = self.tableOfContents.player.currentChapterLocation {
            let spine = self.tableOfContents.networkService.spine
            for index in 0..<spine.count {
                if currentPlayingChapter.inSameChapter(other: spine[index].chapter) {
                    let indexPath = IndexPath(row: index, section: 0)
                    self.tableView.reloadData()
                    self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .top)
                }
            }
        }
    }
    
    @objc func deleteChapterRequested(_ sender: Any) {
        let confirmController = UIAlertController(
            title: "Clear Files",
            message: "Delete files from your local device.",
            preferredStyle: .alert
        )
        confirmController.addAction(
            UIAlertAction(
                title: "Delete",
                style: .destructive,
                handler: { (action) in
                self.tableOfContents.deleteAll()
            })
        )
        confirmController.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel,
                handler: nil
            )
        )
        confirmController.popoverPresentationController?.sourceView = self.view
        self.present(confirmController, animated: true, completion: nil)
    }

    @objc func downloadAllChaptersRequested(_ sender: Any) {
        self.tableOfContents.fetch()
    }
}
