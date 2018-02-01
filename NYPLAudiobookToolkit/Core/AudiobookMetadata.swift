//
//  AudiobookMetadata.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

public class AudiobookMetadata: NSObject {
    let title: String
    let authors: [String]
    let narrators: [String]
    let publishers: [String]
    let published: Date
    let modified: Date
    let language: String
    
    public init(title: String, authors: [String], narrators: [String], publishers: [String], published: Date, modified: Date, language: String) {
        self.title = title
        self.authors = authors
        self.narrators = narrators
        self.publishers = publishers
        self.published = published
        self.modified = modified
        self.language = language
    }
}
