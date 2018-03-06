//
//  DownloadTaskMock.swift
//  NYPLAudiobookToolkitTests
//
//  Created by Dean Silfen on 3/5/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLAudiobookToolkit

typealias TaskCallback = (_ task: DownloadTask) -> Void

class DownloadTaskMock: DownloadTask {
    func fetch() {
        self.fetchClosure?(self)
    }
    
    func delete() { }
    
    let downloadProgress: Float
    
    let key: String
    
    weak var delegate: DownloadTaskDelegate?
    var fetchClosure: TaskCallback?
    public init(progress: Float, key: String, fetchClosure: TaskCallback?) {
        self.downloadProgress = progress
        self.fetchClosure = fetchClosure
        self.key = key
    }
}
