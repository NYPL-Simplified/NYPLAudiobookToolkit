//
//  AudiobookViewController.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/11/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

public class AudiobookViewController: UIViewController {
    private var seekBar = Scrubber()
    private var coverView = UIImageView()
    
    let audiobookMetadata = AudiobookMetadata(title: "Vacationland", authors: ["John Hodgeman"], narrators: ["John Hodgeman"], publishers: ["Random House"], published: Date(), modified: Date(), language: "en")

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.backBarButtonItem?.title = nil
        let bbi = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(AudiobookViewController.tocWasPressed))
        self.navigationItem.rightBarButtonItem = bbi
        self.navigationItem.title = self.audiobookMetadata.title
        self.view.backgroundColor = UIColor.white
        self.coverView.image = UIImage(named: "exampleCover")
        self.coverView.backgroundColor = UIColor.blue
        self.view.addSubview(self.coverView)
        self.coverView.autoPin(toTopLayoutGuideOf: self, withInset: 16)
        self.coverView.autoAlignAxis(.vertical, toSameAxisOf: self.view)
        self.coverView.autoSetDimensions(to: CGSize(width: 300, height: 300))
        
        self.view.addSubview(self.seekBar)
        self.seekBar.autoPinEdge(.top, to: .bottom, of: self.coverView, withOffset: 16)
        self.seekBar.autoPinEdge(.left, to: .left, of: self.view, withOffset: 8)
        self.seekBar.autoPinEdge(.right, to: .right, of: self.view, withOffset: -8)

        self.seekBar.play()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc public func tocWasPressed(_ sender: Any) {
        let tbvc = UITableViewController()
        tbvc.tableView.dataSource = self
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
