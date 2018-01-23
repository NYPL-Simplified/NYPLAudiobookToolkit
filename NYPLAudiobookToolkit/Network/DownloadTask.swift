//
//  DownloadTask.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

protocol DownloadTaskDelegate {
    func downloadTaskDidComplete(_ downloadTask: DownloadTask)
    func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask)
}

protocol DownloadTask {
    func fetch()
    var downloadProgress: Int { get }
    var delegate: DownloadTaskDelegate? { get set }
}
