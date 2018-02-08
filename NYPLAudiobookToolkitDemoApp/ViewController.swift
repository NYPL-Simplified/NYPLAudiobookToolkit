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
        self.loadManifest { [weak self](data) in
            let possibleJson = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let json = possibleJson else { return }
            let metadata = AudiobookMetadata(
                title: "Les Trois Mousquetaires",
                authors: ["Alexandre Dumas"],
                narrators: ["John Hodgeman"],
                publishers: ["LibriVox"],
                published: Date(),
                modified: Date(),
                language: "en"
            )
            guard let manifest = ManifestFactory.manifest(json) else { return }
            let vc = AudiobookDetailViewController(
                audiobookManager: DefaultAudiobookManager(
                    metadata: metadata,
                    manifest: manifest
                )
            )
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func loadManifest(completion: @escaping (_ data: Data) -> Void) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        guard let URL = URL(string: "http://0.0.0.0:8000/tales.audiobook-manifest.json") else {return}
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"
        
        let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if (error == nil) {
                // Success
                let statusCode = (response as! HTTPURLResponse).statusCode
                print("URL Session Task Succeeded: HTTP \(statusCode)")
                guard let data = data else { return }
                DispatchQueue.main.async {
                    completion(data)
                }
            }
            else {
                print("URL Session Task Failed: %@", error!.localizedDescription);
            }
        })
        task.resume()
        session.finishTasksAndInvalidate()
    }
}
