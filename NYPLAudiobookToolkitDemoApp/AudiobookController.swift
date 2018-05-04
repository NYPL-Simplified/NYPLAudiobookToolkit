//
//  AudiobookController.swift
//  NYPLAudiobookToolkitDemoApp
//
//  Created by Dean Silfen on 4/20/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit

class AudiobookController {
    var manager: AudiobookManager?
    func configurePlayhead() {
        guard let manager = self.manager else {
            return
        }
        let cachedPlayhead = FileManager.default.contents(atPath: pathFor(audiobookID: manager.audiobook.uniqueIdentifier)!)
        guard let playheadData = cachedPlayhead else {
            return
        }
        
        let decoder = JSONDecoder()
        guard let location = try? decoder.decode(ChapterLocation.self, from: playheadData) else {
            return
        }
        manager.audiobook.player.movePlayheadToLocation(location)
    }

    init() {
        let json = """
{"spine": [{"title": "Track 1", "findaway:sequence": 1, "href": null, "duration": 16.776, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 2", "findaway:sequence": 2, "href": null, "duration": 10.666, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 3", "findaway:sequence": 3, "href": null, "duration": 10.12, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 4", "findaway:sequence": 4, "href": null, "duration": 54.84, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 5", "findaway:sequence": 5, "href": null, "duration": 195.266, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 6", "findaway:sequence": 6, "href": null, "duration": 426.12, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 7", "findaway:sequence": 7, "href": null, "duration": 448.714, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 8", "findaway:sequence": 8, "href": null, "duration": 446.036, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 9", "findaway:sequence": 9, "href": null, "duration": 417.618, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 10", "findaway:sequence": 10, "href": null, "duration": 373.548, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 11", "findaway:sequence": 11, "href": null, "duration": 403.188, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 12", "findaway:sequence": 12, "href": null, "duration": 401.004, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 13", "findaway:sequence": 13, "href": null, "duration": 496.71, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 14", "findaway:sequence": 14, "href": null, "duration": 530.458, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 15", "findaway:sequence": 15, "href": null, "duration": 360.496, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 16", "findaway:sequence": 16, "href": null, "duration": 358.338, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 17", "findaway:sequence": 17, "href": null, "duration": 389.408, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 18", "findaway:sequence": 18, "href": null, "duration": 355.036, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 19", "findaway:sequence": 19, "href": null, "duration": 362.394, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 20", "findaway:sequence": 20, "href": null, "duration": 396.74, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 21", "findaway:sequence": 21, "href": null, "duration": 492.368, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 22", "findaway:sequence": 22, "href": null, "duration": 491.822, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 23", "findaway:sequence": 23, "href": null, "duration": 472.738, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 24", "findaway:sequence": 24, "href": null, "duration": 476.404, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 25", "findaway:sequence": 25, "href": null, "duration": 467.486, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 26", "findaway:sequence": 26, "href": null, "duration": 358.234, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 27", "findaway:sequence": 27, "href": null, "duration": 322.874, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 28", "findaway:sequence": 28, "href": null, "duration": 461.038, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 29", "findaway:sequence": 29, "href": null, "duration": 468.734, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 30", "findaway:sequence": 30, "href": null, "duration": 413.666, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 31", "findaway:sequence": 31, "href": null, "duration": 387.224, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 32", "findaway:sequence": 32, "href": null, "duration": 427.94, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 33", "findaway:sequence": 33, "href": null, "duration": 381.27, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 34", "findaway:sequence": 34, "href": null, "duration": 379.268, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 35", "findaway:sequence": 35, "href": null, "duration": 417.488, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 36", "findaway:sequence": 36, "href": null, "duration": 462.364, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 37", "findaway:sequence": 37, "href": null, "duration": 524.842, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 38", "findaway:sequence": 38, "href": null, "duration": 503.184, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 39", "findaway:sequence": 39, "href": null, "duration": 471.516, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 40", "findaway:sequence": 40, "href": null, "duration": 487.35, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 41", "findaway:sequence": 41, "href": null, "duration": 347.184, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 42", "findaway:sequence": 42, "href": null, "duration": 323.862, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 43", "findaway:sequence": 43, "href": null, "duration": 31.206, "findaway:part": 0, "type": "audio/mpeg"}], "@context": ["http://readium.org/webpub/default.jsonld", {"findaway": "http://librarysimplified.org/terms/third-parties/findaway.com/"}], "links": [{"href": "http://book-covers.nypl.org/scaled/300/Content%20Cafe/ISBN/9780735289215/cover.jpg", "rel": "cover"}], "metadata": {"language": "en", "title": "Tales of the Peculiar", "encrypted": {"findaway:accountId": "3M-a4tmf", "findaway:checkoutId": "5aecb2c63073726ecb9ce048", "findaway:sessionKey": "0400fc84-0c48-4a77-9a72-fa6b1e7d29b1", "findaway:fulfillmentId": "122258", "findaway:licenseId": "58e25e5b9307d522c76effa9", "scheme": "http://librarysimplified.org/terms/drm/scheme/FAE"}, "authors": ["Ransom Riggs"], "duration": 16023.538, "identifier": "urn:librarysimplified.org/terms/id/Bibliotheca%20ID/k3s6or9", "@type": "http://bib.schema.org/Audiobook"}}
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
        
        guard let audiobook = AudiobookFactory.audiobook(unwrappedJSON) else { return }
        if (self.manager == nil) {
            self.manager = DefaultAudiobookManager(
                metadata: metadata,
                audiobook: audiobook
            )
        }
    }
    
    func pathFor(audiobookID: String) -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsURL = NSURL(fileURLWithPath: paths.first!, isDirectory: true)
        let fullURL = documentsURL.appendingPathComponent("\(audiobookID).playhead")
        return fullURL?.path
    }

    public func savePlayhead() {
        guard let chapter = self.manager?.audiobook.player.currentChapterLocation else {
            return
        }
        let encoder = JSONEncoder()
        if let encodedChapter = try? encoder.encode(chapter) {
            FileManager.default.createFile(atPath: pathFor(audiobookID: chapter.audiobookID)!, contents: encodedChapter, attributes: nil)
        }
    }
}
