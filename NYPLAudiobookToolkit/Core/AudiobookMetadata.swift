//
//  AudiobookMetadata.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objcMembers public final class AudiobookMetadata: NSObject {
    public let title: String
    public let authors: [String]
    public let narrators: [String]
    public let publishers: [String]
    public let published: Date
    public let modified: Date
    public let language: String
    
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
