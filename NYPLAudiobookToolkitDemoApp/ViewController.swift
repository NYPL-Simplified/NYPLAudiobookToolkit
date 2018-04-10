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
    var detailVC: AudiobookPlayerViewController?
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
      "duration": 3749.386,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 2",
      "findaway:sequence": 2,
      "href": null,
      "duration": 3005.262,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 3",
      "findaway:sequence": 3,
      "href": null,
      "duration": 3949.85,
      "findaway:part": 0,
      "type": "audio/mpeg"
    },
    {
      "title": "Track 4",
      "findaway:sequence": 4,
      "href": null,
      "duration": 2859.943,
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
      "href": "http://book-covers.nypl.org/scaled/300/Content%20Cafe/ISBN/9780743585149/cover.jpg",
      "rel": "cover"
    }
  ],
  "metadata": {
    "language": "en",
    "title": "Star Trek: The Original Series: Vulcan's Soul #1: Exodus",
    "encrypted": {
      "findaway:accountId": "3M",
      "findaway:checkoutId": "5ab415fa307372541b9ce044",
      "findaway:sessionKey": "49fc2f9b-9d6a-4865-9e8e-22af3b44f145",
      "findaway:fulfillmentId": "33732",
      "findaway:licenseId": "579b6aabb692b15832c06860",
      "scheme": "http://librarysimplified.org/terms/drm/scheme/FAE"
    },
    "authors": [
      "Susan Shwartz",
      "Josepha Sherman"
    ],
    "duration": 13564.440999999999,
    "identifier": "urn:librarysimplified.org/terms/id/Bibliotheca%20ID/eb5ucz9",
    "@type": "http://bib.schema.org/Audiobook"
  }
}
"""
        guard let data = json.data(using: String.Encoding.utf8) else { return }
        let possibleJson = try? JSONSerialization.jsonObject(with: data, options: [])
        guard let unwrappedJSON = possibleJson as? [String: Any] else { return }
        guard let JSONmetadata = unwrappedJSON["metadata"] as? [String: Any] else { return }
        guard let title = JSONmetadata["title"] as? String else {
            return
        }
        guard let authors = JSONmetadata["authors"] as? [String] else {
            return
        }
        let metadata = AudiobookMetadata(
            title: title,
            authors: authors,
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
            self.detailVC = AudiobookPlayerViewController(
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
