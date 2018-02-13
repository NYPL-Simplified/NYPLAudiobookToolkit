//
//  FindawayTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine


class FindawayTableOfContents: TableOfContents, FindawayDownloadNotificationHandlerDelegate {
    func findawayDownloadNotificationHandler(_ findawayDownloadNotificationHandler: FindawayDownloadNotificationHandler, didDetectDownload chapter: FAEChapterDescription) {

    }
    
    let elements: [TOCElement]
    weak var delegate: TableOfContentsDelegate?
    private let eventHandler: FindawayDownloadNotificationHandler
    init(spineJSON: [[String: Any]], eventHandler: FindawayDownloadNotificationHandler) {
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
                hasLocalFile: false,
                playbackDescription: description
            )
        }
        self.eventHandler = eventHandler
        eventHandler.delegate = self
    }
}
