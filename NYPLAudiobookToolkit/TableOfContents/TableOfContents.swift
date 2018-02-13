//
//  TableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc public protocol TOCElement {
    var title: String { get }
    var isAvailableForPlayback: Bool { get }
    var playbackDescription: ChapterDescription { get }
}

@objc public protocol TableOfContents {
    var elements: [TOCElement] { get }
}

class DefaultTOCElement: TOCElement {
    var title: String
    var isAvailableForPlayback: Bool
    var playbackDescription: ChapterDescription
    init(title: String, isAvailableForPlayback: Bool, playbackDescription: ChapterDescription) {
        self.title = title
        self.isAvailableForPlayback = isAvailableForPlayback
        self.playbackDescription = playbackDescription
    }
}
