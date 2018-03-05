//
//  DownloadTaskMock.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/5/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit

class DownloadTaskMock: DownloadTask {
    func fetch() { }
    
    func delete() { }
    
    let downloadProgress: Float
    
    let key: String
    
    weak var delegate: DownloadTaskDelegate?
    
    public init(progress: Float, key: String) {
        self.downloadProgress = progress
        self.key = key
    }
}
