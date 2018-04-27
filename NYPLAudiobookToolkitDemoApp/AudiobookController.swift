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
{"spine": [{"title": "Track 1", "findaway:sequence": 1, "href": null, "duration": 3749.386, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 2", "findaway:sequence": 2, "href": null, "duration": 3005.262, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 3", "findaway:sequence": 3, "href": null, "duration": 3949.85, "findaway:part": 0, "type": "audio/mpeg"}, {"title": "Track 4", "findaway:sequence": 4, "href": null, "duration": 2859.943, "findaway:part": 0, "type": "audio/mpeg"}], "@context": ["http://readium.org/webpub/default.jsonld", {"findaway": "http://librarysimplified.org/terms/third-parties/findaway.com/"}], "links": [{"href": "http://book-covers.nypl.org/scaled/300/Content%20Cafe/ISBN/9780743585149/cover.jpg", "rel": "cover"}], "metadata": {"language": "en", "title": "Star Trek: The Original Series: Vulcan's Soul #1: Exodus", "encrypted": {"findaway:accountId": "3M", "findaway:checkoutId": "5ad0eea930737269dc9ce04b", "findaway:sessionKey": "81fca5be-2107-4beb-9676-1810645e7e6c", "findaway:fulfillmentId": "33732", "findaway:licenseId": "579b6aabb692b15832c06860", "scheme": "http://librarysimplified.org/terms/drm/scheme/FAE"}, "authors": ["Susan Shwartz", "Josepha Sherman"], "duration": 13564.440999999999, "identifier": "urn:librarysimplified.org/terms/id/Bibliotheca%20ID/eb5ucz9", "@type": "http://bib.schema.org/Audiobook"}}
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
