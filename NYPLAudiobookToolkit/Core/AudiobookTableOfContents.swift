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

/// This class may be used in conjunction with a UITableView
/// to create a fully functioning Table of Contents UI for the
/// current audiobook. To get a functioning ToC that works
/// out of the box, construct a
/// AudiobookTableOfContentsTableViewController.
public final class AudiobookTableOfContents: NSObject {
    
    public var downloadProgress: Float {
        return self.networkService.downloadProgress
    }

    /// Download all available files from network  for the current audiobook.
    public func fetch() {
        self.networkService.fetch()
    }

    /// Delete all available files for the current audiobook.
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
        let spineElement = self.networkService.spine[indexPath.row]

        // This assumes the player can handle this command before a
        // chapter has been downloaded. AudioEngine can handle this
        // use case, and AVPlayer should as well. However it is an
        // implied requirement of the player that has not been
        // explicitly stated elsewhere.
        self.player.playAtLocation(spineElement.chapter)
    }
}


extension AudiobookTableOfContents: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.networkService.spine.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: AudiobookTableOfContentsTableViewControllerCellIdentifier)
        let spineElement = self.networkService.spine[indexPath.row]
        let config = self.configFor(spineElement)
        cell.textLabel?.text = config.title
        cell.detailTextLabel?.text = config.detailLabel
        cell.backgroundColor = config.backgroundColor
        cell.selectionStyle = .none
        let playingChapter = self.player.currentChapterLocation?.inSameChapter(other: spineElement.chapter) ?? false
        if playingChapter {
            cell.contentView.layer.borderColor = UIColor.red.cgColor
            cell.contentView.layer.borderWidth = 1
        }
        return cell
    }
    
    func configFor(_ spineElement: SpineElement) -> (title: String?, detailLabel: String, backgroundColor: UIColor) {
        let progress = spineElement.downloadTask.downloadProgress
        let title = spineElement.chapter.title
        let detailLabel: String
        let backgroundColor: UIColor
        if progress == 0 {
            detailLabel = NSLocalizedString("Not Downloaded", bundle: Bundle.audiobookToolkit()!, value: "Not Downloaded", comment: "Track has not been  downloaded to the user's phone")
            backgroundColor = UIColor.lightGray
        } else if progress > 0 && progress < 1  {
            let percentage = HumanReadablePercentage(percentage: progress).value
            let labelFormat = NSLocalizedString("Downloading %@", bundle: Bundle.audiobookToolkit()!, value: "Downloading %@", comment: "The percentage of the chapter that has been downloaded, formatting for string should be localized at this point.")
            detailLabel = String(format: labelFormat, percentage)
            backgroundColor = UIColor.lightGray
        } else {
            let duration = HumanReadableTimestamp(timeInterval: spineElement.chapter.duration).value
            let labelFormat = NSLocalizedString("Duration %@", bundle: Bundle.audiobookToolkit()!, value: "Duration %@", comment: "Duration of the track, with formatting for a previously localized string to be inserted.")
            detailLabel = String(format: labelFormat, duration)
            backgroundColor = UIColor.white
        }
        return (title: title, detailLabel: detailLabel, backgroundColor: backgroundColor)
    }
}


extension AudiobookTableOfContents: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
    
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }

    public func player(_ player: Player, didComplete chapter: ChapterLocation) { }
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
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didDeleteFileFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
}
