//
//  AudiobookTableOfContentsTableViewController.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class AudiobookTableOfContentsTableViewController: UITableViewController, AudiobookTableOfContentsDelegate {

    func audiobookTableOfContentsDidRequestReload(_ audiobookTableOfContents: AudiobookTableOfContents) {
        self.tableView.reloadData()
    }

    let tableOfContents: AudiobookTableOfContents
    public init(tableOfContents: AudiobookTableOfContents) {
        self.tableOfContents = tableOfContents
        super.init(nibName: nil, bundle: nil)
        self.title = "Table Of Contents"
        self.tableOfContents.delegate = self
        self.tableView.dataSource = self.tableOfContents
        self.tableView.delegate = self.tableOfContents
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
