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

    var manager: AudiobookManager?
    var detailVC: AudiobookDetailViewController?
    override func viewDidAppear(_ animated: Bool) {
//        self.loadAudiobook { (data) in
//
//        }
//        guard let json = possibleJson else { return }
        
        guard let data = json.data(using: String.Encoding.utf8) else { return }
        let possibleJson = try? JSONSerialization.jsonObject(with: data, options: [])
        guard let unwrappedJSON = possibleJson else { return }
        let metadata = AudiobookMetadata(
            title: "The Heart of Henry Quantum",
            authors: ["Alexandre Dumas"],
            narrators: ["John Hodgeman"],
            publishers: ["Findaway"],
            published: Date(),
            modified: Date(),
            language: "en"
        )
        
        self.navigationItem.title = "The Heart of Henry Quantum"
        guard let audiobook = AudiobookFactory.audiobook(unwrappedJSON) else { return }
        if (self.manager == nil) {
            self.manager = DefaultAudiobookManager(
                metadata: metadata,
                audiobook: audiobook
            )
        }
        guard let theManager = self.manager else { return }
        if (self.detailVC == nil) {
            self.detailVC = AudiobookDetailViewController(
                audiobookManager: theManager
            )
        }
        guard let vc = self.detailVC else { return }
        
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

    func loadAudiobook(completion: @escaping (_ data: Data) -> Void) {
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
