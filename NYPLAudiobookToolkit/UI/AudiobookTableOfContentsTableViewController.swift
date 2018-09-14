//
//  AudiobookTableOfContentsTableViewController.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

let AudiobookTableOfContentsTableViewControllerCellIdentifier = "AudiobookTableOfContentsTableViewControllerCellIdentifier"

public class AudiobookTableOfContentsTableViewController: UITableViewController, AudiobookTableOfContentsDelegate {

    //MARK: - AudiobookTableOfContentsDelegate

    func audiobookTableOfContentsDidRequestReload(_ audiobookTableOfContents: AudiobookTableOfContents) {

        if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.reloadData()
            self.tableView.selectRow(at: selectedIndexPath, animated: true, scrollPosition: .middle)
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

    //MARK: -

    let tableOfContents: AudiobookTableOfContents
    private let activityIndicator: UIActivityIndicatorView
    public init(tableOfContents: AudiobookTableOfContents) {
        self.tableOfContents = tableOfContents
        self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        self.activityIndicator.hidesWhenStopped = true
        super.init(nibName: nil, bundle: nil)
        let deleteItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(AudiobookTableOfContentsTableViewController.deleteChapterRequested(_:))
        )
        let downloadAllItem = UIBarButtonItem(
            title: "Download All",
            style: .plain,
            target: self,
            action: #selector(AudiobookTableOfContentsTableViewController.downloadAllChaptersRequested(_:)))
        let activityItem = UIBarButtonItem(
            customView: self.activityIndicator)
        self.navigationItem.rightBarButtonItems = [ downloadAllItem, deleteItem, activityItem ]
        self.tableOfContents.delegate = self
        self.tableView.dataSource = self.tableOfContents
        self.tableView.delegate = self.tableOfContents
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
