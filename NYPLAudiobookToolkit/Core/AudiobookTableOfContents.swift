//
//  AudiobookTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

protocol AudiobookTableOfContentsDelegate: class {
    func audiobookTableOfContentsDidRequestReload(_ audiobookTableOfContents: AudiobookTableOfContents)
}

public final class AudiobookTableOfContents: NSObject {
    public func fetch() {
        self.networkService.fetch()
    }

    public func deleteAll() {
        self.networkService.deleteAll()
    }
    
    weak var delegate: AudiobookTableOfContentsDelegate?
    private let networkService: AudiobookNetworkService
    private let player: Player
    internal init(networkService: AudiobookNetworkService, player: Player) {
        self.networkService = networkService
        self.player = player
        super.init()
        self.player.registerDelegate(self)
        self.networkService.registerDelegate(self)
    }
    
    deinit {
        self.player.removeDelegate(self)
        self.networkService.removeDelegate(self)
    }
}

extension AudiobookTableOfContents: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.networkService.fetchSpineAt(index: indexPath.row)
        let spineElement = self.networkService.spine[indexPath.row]
        
        // This assumes the player can handle this command before a
        // chapter has been downloaded. AudioEngine can handle this
        // use case, and AVPlayer should as well. However it is an
        // implied requirement of the player that has not been
        // explicitly stated elsewhere.
        self.player.jumpToLocation(spineElement.chapter)
    }
}


extension AudiobookTableOfContents: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.networkService.spine.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let spineElement = self.networkService.spine[indexPath.row]
        cell.textLabel?.text = spineElement.chapter.title
        cell.detailTextLabel?.text = self.subtitleFor(spineElement)
        cell.selectionStyle = .none
        
        if self.player.chapterIsPlaying(spineElement.chapter) {
            cell.contentView.layer.borderColor = UIColor.red.cgColor
            cell.contentView.layer.borderWidth = 1
        }
        return cell
    }
    
    func subtitleFor(_ spineElement: SpineElement) -> String {
        let progress = spineElement.downloadTask.downloadProgress
        if progress == 0 {
            return "Not Downloaded"
        } else if progress > 0 && progress < 1  {
            let label = HumanReadablePercentage(percentage: progress).value
            return "Downloading \(label)%"
        } else {
            let duration = HumanReadableTimeInterval(timeInterval: spineElement.chapter.duration).value
            return "Duration \(duration)"
        }
        
    }
}


extension AudiobookTableOfContents: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
    
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
}

extension AudiobookTableOfContents: AudiobookNetworkServiceDelegate {
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didReceive error: NSError, for spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
}
