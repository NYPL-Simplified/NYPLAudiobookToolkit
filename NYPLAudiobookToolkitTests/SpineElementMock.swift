//
//  SpineElementMock.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/5/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit

class SpineElementMock: SpineElement {
    var key: String
    
    var downloadTask: DownloadTask
    
    var chapter: ChapterLocation
    
    public init(key: String, downloadTask: DownloadTask, chapter: ChapterLocation) {
        self.key = key
        self.downloadTask = downloadTask
        self.chapter = chapter
    }
}
