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

    func audiobookTableOfContentsDidRequestReload(_ audiobookTableOfContents: AudiobookTableOfContents) {
        self.tableView.reloadData()
    }

    let tableOfContents: AudiobookTableOfContents
    public init(tableOfContents: AudiobookTableOfContents) {
        self.tableOfContents = tableOfContents
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
        self.navigationItem.rightBarButtonItems = [ downloadAllItem, deleteItem ]
        self.tableOfContents.delegate = self
        self.tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: AudiobookTableOfContentsTableViewControllerCellIdentifier
        )
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
