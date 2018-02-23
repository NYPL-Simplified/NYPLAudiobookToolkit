//
//  AudiobookTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

public final class AudiobookTableOfContentsDataSource: NSObject, AudiobookNetworkServiceDelegate, PlayerDelegate, UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.networkService.spine.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let spineElement = self.networkService.spine[indexPath.row]
        cell.textLabel?.text = spineElement.chapter.title
        cell.detailTextLabel?.text = "Download %\(spineElement.downloadTask.downloadProgress)"
        if self.player.chapterIsPlaying(spineElement.chapter) {
            cell.isSelected = true
        }
        return cell
    }

    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.tableView?.reloadData()
    }
    
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.tableView?.reloadData()
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) {
        self.tableView?.reloadData()
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement) {
        self.tableView?.reloadData()
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didErrorFor spineElement: SpineElement) {
        self.tableView?.reloadData()
    }
    
    public weak var tableView: UITableView?
    private let networkService: AudiobookNetworkService
    private let player: Player
    internal init(networkService: AudiobookNetworkService, player: Player) {
        self.networkService = networkService
        self.player = player
    }
}
