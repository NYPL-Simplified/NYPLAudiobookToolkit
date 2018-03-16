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
        let json = """
{
  "spine": [
    {
      "title": "Track 1",
      "findaway:sequence": 1,
      "href": null,
      "duration": 41.346,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 2",
      "findaway:sequence": 2,
      "href": null,
      "duration": 1736.598,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 3",
      "findaway:sequence": 3,
      "href": null,
      "duration": 1424.39,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 4",
      "findaway:sequence": 4,
      "href": null,
      "duration": 1144.604,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 5",
      "findaway:sequence": 5,
      "href": null,
      "duration": 1776.638,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 6",
      "findaway:sequence": 6,
      "href": null,
      "duration": 2720.23,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 7",
      "findaway:sequence": 7,
      "href": null,
      "duration": 1295.378,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 8",
      "findaway:sequence": 8,
      "href": null,
      "duration": 2422.114,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 9",
      "findaway:sequence": 9,
      "href": null,
      "duration": 2797.84,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 10",
      "findaway:sequence": 10,
      "href": null,
      "duration": 956.754,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 11",
      "findaway:sequence": 11,
      "href": null,
      "duration": 1445.71,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 12",
      "findaway:sequence": 12,
      "href": null,
      "duration": 1061.638,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 13",
      "findaway:sequence": 13,
      "href": null,
      "duration": 1429.616,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 14",
      "findaway:sequence": 14,
      "href": null,
      "duration": 1640.97,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 15",
      "findaway:sequence": 15,
      "href": null,
      "duration": 242.43,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 16",
      "findaway:sequence": 16,
      "href": null,
      "duration": 112.56,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 17",
      "findaway:sequence": 17,
      "href": null,
      "duration": 64.486,
      "findaway:part": 0,
      "type": "audio/mpeg"
    }
  ],
  "@context": [
    "http://readium.org/webpub/default.jsonld",
    {
      "findaway": "http://librarysimplified.org/terms/third-parties/findaway.com/"
    }
  ],
  "links": [
    {
      "href": "http://book-covers.nypl.org/scaled/300/Content%20Cafe/ISBN/9781508223368/cover.jpg",
      "rel": "cover"
    }
  ],
  "metadata": {
    "language": "en",
    "title": "Heart of Henry Quantum, The",
    "encrypted": {
      "findaway:accountId": "3M",
      "findaway:checkoutId": "5a96c36b58a1100f6f0ca03f",
      "findaway:sessionKey": "2cd932a0-fa32-4bf4-9b36-c5f7106ffa30",
      "findaway:fulfillmentId": "123520",
      "findaway:licenseId": "580f0f99aacbcc6845a7b7ed",
      "scheme": "http://librarysimplified.org/terms/drm/scheme/FAE"
    },
    "authors": [
      "Pepper Harding"
    ],
    "duration": 22313.302000000003,
    "identifier": "urn:librarysimplified.org/terms/id/Bibliotheca%20ID/k6utn89",
    "@type": "http://bib.schema.org/Audiobook"
  }
}
"""
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
        
        self.navigationItem.title = "My Books"
        
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
