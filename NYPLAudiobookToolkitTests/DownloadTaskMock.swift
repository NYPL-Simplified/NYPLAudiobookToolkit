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
        guard let fetchClosure = self.fetchClosure else { return }
        // Call the closure async to prevent temporal dependencies.
        DispatchQueue.main.async { [weak self] () -> Void in
            if let strongSelf = self {
                fetchClosure(strongSelf)
            }
        }
    }
    
    func delete() { }
  
    func cancel() { }
    
    let downloadProgress: Float
    
    var downloadCompleted: Bool {
        return false
    }

    let key: String
    
    weak var delegate: DownloadTaskDelegate?
    var fetchClosure: TaskCallback?
    public init(progress: Float, key: String, fetchClosure: TaskCallback?) {
        self.downloadProgress = progress
        self.fetchClosure = fetchClosure
        self.key = key
    }
}
