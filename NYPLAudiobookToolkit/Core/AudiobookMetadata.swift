//
//  AudiobookMetadata.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import Foundation

@objcMembers public final class AudiobookMetadata: NSObject {
    public let title: String?
    public let authors: [String]?
    
    public init(title: String?, authors: [String]?) {
        self.title = title
        self.authors = authors
    }
}
