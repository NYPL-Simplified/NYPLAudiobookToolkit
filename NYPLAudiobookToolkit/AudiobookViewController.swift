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

    let audiobookMetadata = AudiobookMetadata(title: "Vacationland", authors: ["John Hodgeman"], narrators: ["John Hodgeman"], publishers: ["Random House"], published: Date(), modified: Date(), language: "en")

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.backBarButtonItem?.title = nil
        self.navigationItem.title = self.audiobookMetadata.title
        self.view.backgroundColor = UIColor.red
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let label = UILabel()
        label.text = "welocome to audiobooks"
        label.backgroundColor = UIColor.cyan
        self.view.addSubview(label)
        label.autoCenterInSuperview()
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
