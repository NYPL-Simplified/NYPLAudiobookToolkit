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
    var hasLocalFile: Bool { get }
    var playbackDescription: ChapterDescription { get }
}

@objc public protocol TableOfContentsDelegate: class {
    func tableOfContentsDidUpdate(_ tableOfContents: TableOfContents)
}

@objc public protocol TableOfContents {
    var elements: [TOCElement] { get }
    weak var delegate: TableOfContentsDelegate? { get set }
}

class DefaultTOCElement: TOCElement {
    var title: String
    var hasLocalFile: Bool
    var playbackDescription: ChapterDescription
    init(title: String, hasLocalFile: Bool, playbackDescription: ChapterDescription) {
        self.title = title
        self.hasLocalFile = hasLocalFile
        self.playbackDescription = playbackDescription
    }
}
