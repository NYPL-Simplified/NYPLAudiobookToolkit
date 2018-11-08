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

public class AudiobookTableOfContentsTableViewController: UITableViewController {

    let tableOfContents: AudiobookTableOfContents
    let delegate: AudiobookTableOfContentsTableViewControllerDelegate
    private let activityIndicator: UIActivityIndicatorView
    public init(tableOfContents: AudiobookTableOfContents, delegate: AudiobookTableOfContentsTableViewControllerDelegate) {
        self.tableOfContents = tableOfContents
        self.delegate = delegate
        self.activityIndicator = UIActivityIndicatorView(style: .gray)
        self.activityIndicator.hidesWhenStopped = true
        super.init(nibName: nil, bundle: nil)
        let activityItem = UIBarButtonItem(customView: self.activityIndicator)
        self.navigationItem.rightBarButtonItems = [activityItem]
        self.tableOfContents.delegate = self
        self.tableView.dataSource = self.tableOfContents
        self.tableView.delegate = self.tableOfContents
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let index = self.tableOfContents.currentSpineIndex() {
            self.tableView.reloadData()
            if self.tableView.numberOfRows(inSection: 0) > index {
                let indexPath = IndexPath(row: index, section: 0)
                self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .top)
                self.announceTrackIfNeeded(track: indexPath)
            }
        }
    }

    private func announceTrackIfNeeded(track: IndexPath) {
        if UIAccessibility.isVoiceOverRunning {
            let cell = self.tableView.cellForRow(at: track)
            let accessibleString = NSLocalizedString("Currently Playing: %@",
                                                     bundle: Bundle.audiobookToolkit()!,
                                                     value: "Currently Playing: %@",
                                                     comment: "Announce which track is highlighted in the table of contents.")
            if let text = cell?.textLabel?.text {
                UIAccessibility.post(notification: .screenChanged, argument: String(format: accessibleString, text))
            }
        }
    }
}

extension AudiobookTableOfContentsTableViewController: AudiobookTableOfContentsDelegate {
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
        self.delegate.userSelectedSpineItem(item: spineItem)
    }
}
