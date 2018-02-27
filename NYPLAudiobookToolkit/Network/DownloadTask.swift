//
//  DownloadTask.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//


/// Notifications about the status of the download.
@objc public protocol DownloadTaskDelegate: class {
    func downloadTaskDidDeleteAsset(_ downloadTask: DownloadTask)
    func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask)
    func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask)
    func downloadTask(_ downloadTask: DownloadTask, didRecieve error: NSError)
}

/// Protocol to handle hitting the network to download an audiobook.
/// Implementers of this protocol should handle the download with one source.
/// There should be multiple objects that implement DownloadTask, each working
/// with a different Network API.
/// For example, one for AudioEngine networking, one for URLSession, etc.
///
/// If a DownloadTask is attempting to download a file that is already available
/// locally, it should notify it's delegates as if it were a successful download.
@objc public protocol DownloadTask: class {
    func fetch()
    func delete()
    var downloadProgress: Float { get }
    var key: String { get }
    weak var delegate: DownloadTaskDelegate? { get set }
}
