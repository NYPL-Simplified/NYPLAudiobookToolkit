//
//  AudiobookTableOfContentsTableViewController.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class AudiobookTableOfContentsTableViewController: UITableViewController {
    let dataSource: AudiobookTableOfContentsDataSource
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    public init(dataSource: AudiobookTableOfContentsDataSource) {
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
        self.title = "Table Of Contents"
        self.dataSource.tableView = self.tableView
        self.tableView.dataSource = self.dataSource
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
