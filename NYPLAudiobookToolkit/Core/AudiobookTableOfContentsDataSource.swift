//
//  AudiobookTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

protocol AudiobookTableOfContentsDataSourceDelegate: class {
    func audiobookTableOfContentsDataSourceDidRequestReload(_ audiobookTableOfContentsDataSource: AudiobookTableOfContentsDataSource)
}

public final class AudiobookTableOfContentsDataSource: NSObject, AudiobookNetworkServiceDelegate, PlayerDelegate, UITableViewDataSource, UITableViewDelegate {

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.networkService.fetchSpineAt(index: indexPath.row)
        let spineElement = self.networkService.spine[indexPath.row]
        self.player.jumpToLocation(spineElement.chapter)
        let cell = tableView.cellForRow(at: indexPath)
        cell?.isSelected = true
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.networkService.spine.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let spineElement = self.networkService.spine[indexPath.row]
        cell.textLabel?.text = spineElement.chapter.title
        cell.detailTextLabel?.text = self.subtitleFor(spineElement)
        if self.player.chapterIsPlaying(spineElement.chapter) {
            cell.isSelected = true
        }
        return cell
    }
    
    func subtitleFor(_ spineElement: SpineElement) -> String {
        if spineElement.downloadTask.downloadProgress < 1 {
            return "Download %\(spineElement.downloadTask.downloadProgress)"
        } else {
            let duration = HumanReadableTimeInterval(timeInterval: spineElement.chapter.duration).value
            return "Duration \(duration)"
        }
    }

    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDataSourceDidRequestReload(self)
    }
    
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDataSourceDidRequestReload(self)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDataSourceDidRequestReload(self)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDataSourceDidRequestReload(self)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didErrorFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDataSourceDidRequestReload(self)
    }
    
    weak var delegate: AudiobookTableOfContentsDataSourceDelegate?
    private let networkService: AudiobookNetworkService
    private let player: Player
    internal init(networkService: AudiobookNetworkService, player: Player) {
        self.networkService = networkService
        self.player = player
    }
}
