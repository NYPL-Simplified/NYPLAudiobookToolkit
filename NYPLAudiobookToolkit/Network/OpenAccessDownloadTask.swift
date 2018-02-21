//
//  OpenAccessDownloadTask.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/30/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class OpenAccessDownloadTask: DownloadTask {
    var downloadProgress: Float {
        return 0
    }
    
    let key: String
    public init(spineElement: SpineElement) {
        self.key = spineElement.key
    }

    var error: AudiobookError?
    
    weak var delegate: DownloadTaskDelegate?

    func fetch() {
    }
}
