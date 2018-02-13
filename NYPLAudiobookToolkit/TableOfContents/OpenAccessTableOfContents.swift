//
//  OpenAccessTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class OpenAccessTableOfContents: TableOfContents {
    var elements: [TOCElement]
    weak var delegate: TableOfContentsDelegate?
    init(JSON: [String: Any]) {
        self.elements = []
    }
}
