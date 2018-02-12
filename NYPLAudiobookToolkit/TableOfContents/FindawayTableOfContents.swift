//
//  FindawayTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class FindawayTableOfContents: TableOfContents {
    var elements: [TOCElement]
    init(spineJSON: [[String: Any]]) {
        self.elements = spineJSON.flatMap { (possibleTOCElement) -> TOCElement? in
            guard let title = possibleTOCElement["title"] as? String else { return nil }
            guard let chapterNumber = possibleTOCElement["findaway:sequence"] as? UInt else { return nil }
            guard let partNumber = possibleTOCElement["findaway:part"] as? UInt else { return nil }
            guard let duration = possibleTOCElement["duration"] as? TimeInterval else { return nil }
            let description = DefaultChapterDescription(
                number: chapterNumber,
                part: partNumber,
                duration: duration,
                offset: 0
            )
            return DefaultTOCElement(
                title: title,
                isAvailableForPlayback: false,
                playbackDescription: description
            )
        }
    }
}
