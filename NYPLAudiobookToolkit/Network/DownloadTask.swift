//
//  DownloadTask.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

protocol DownloadTaskDelegate: class {
    func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask)
    func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask)
    func downloadTaskDidError(_ downloadTask: DownloadTask)
}

protocol DownloadTask {
    func fetch()
    var downloadProgress: Float { get }
    var error: AudiobookError? { get }
    var delegate: DownloadTaskDelegate? { get set }
}
