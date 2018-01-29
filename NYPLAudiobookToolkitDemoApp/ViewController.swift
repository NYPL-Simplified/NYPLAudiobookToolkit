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

        let possibleJson = try? JSONSerialization.jsonObject(with: data, options: [])
        guard let json = possibleJson else { return }
        guard let manifest = AudiobookManifest(JSON: json) else { return }
        let vc = AudiobookDetailViewController(
            audiobookManager: DefaultAudiobookManager(
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

