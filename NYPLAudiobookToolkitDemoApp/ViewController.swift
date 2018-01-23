//
//  ViewController.swift
//  NYPLAudiobookToolkitDemoApp
//
//  Created by Dean Silfen on 1/16/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit

class ViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        let metadata = AudiobookMetadata(
            title: "Les Trois Mousquetaires",
            authors: ["Alexandre Dumas"],
            narrators: ["John Hodgeman"],
            publishers: ["LibriVox"],
            published: Date(),
            modified: Date(),
            language: "en"
        )
        let manifest = AudiobookManifest(placeholder: "")
        let vc = AudiobookDetailViewController(
            audiobookManager: AudiobookManager(
                metadata: metadata,
                manifest: manifest
            )
        )
        self.navigationController?.pushViewController(vc, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

