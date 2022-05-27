//
//  AudiobookTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLUtilitiesObjc

protocol AudiobookTableOfContentsDelegate: AnyObject {
    func audiobookTableOfContentsDidRequestReload(_ audiobookTableOfContents: AudiobookTableOfContents)
    func audiobookTableOfContentsPendingStatusDidUpdate(inProgress: Bool)
    func audiobookTableOfContentsUserSelected(spineItem: SpineElement)
}

/// This class may be used in conjunction with a UITableView to create a fully functioning Table of
/// Contents UI for the current audiobook. To get a functioning ToC that works out of the box,
/// construct a AudiobookTableOfContentsTableViewController.
public final class AudiobookTableOfContents: NSObject {
    
    public var downloadProgress: Float {
        return self.networkService.downloadProgress
    }

    /// Download all available files from network for the current audiobook.
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

    func currentSpineIndex() -> Int? {
        if let currentPlayingChapter = self.player.currentChapterLocation {
            let spine = self.networkService.spine
            for index in 0..<spine.count {
                if currentPlayingChapter.inSameChapter(other: spine[index].chapter) {
                    return index
                }
            }
        }
        return nil
    }
}

extension AudiobookTableOfContents: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let spineElement = self.networkService.spine[indexPath.row]
        self.player.playAtLocation(spineElement.chapter)
        self.delegate?.audiobookTableOfContentsUserSelected(spineItem: spineElement)
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: true)
    }
}


extension AudiobookTableOfContents: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.networkService.spine.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let spineElement = self.networkService.spine[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: AudiobookTableOfContentsTableViewControllerCellIdentifier) as? AudiobookTrackTableViewCell {
            cell.configureFor(spineElement)
            return cell
        } else {
            let cell = AudiobookTrackTableViewCell(style: .value1, reuseIdentifier:AudiobookTableOfContentsTableViewControllerCellIdentifier)
            cell.configureFor(spineElement)
            return cell
        }
    }
}


extension AudiobookTableOfContents: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: false)
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
    
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: false)
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }

    public func player(_ player: Player, didFailPlaybackOf chapter: ChapterLocation, withError error: NSError?) { }
    public func player(_ player: Player, didComplete chapter: ChapterLocation) { }
    public func playerDidUnload(_ player: Player) { }
}

extension AudiobookTableOfContents: AudiobookNetworkServiceDelegate {
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didReceive error: NSError?, for spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: false)
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didCompleteDownloadFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: false)
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }

    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didUpdateProgressFor spineElement: SpineElement)
    {
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: false)
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didDeleteFileFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: false)
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }

    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didUpdateOverallDownloadProgress progress: Float) {
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didTimeoutFor spineElement: SpineElement?,
                                        networkStatus: NetworkStatus) {
        self.delegate?.audiobookTableOfContentsPendingStatusDidUpdate(inProgress: false)
        self.delegate?.audiobookTableOfContentsDidRequestReload(self)
    }
  
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        downloadExceededTimeLimitFor spineElement: SpineElement,
                                        elapsedTime: TimeInterval,
                                        networkStatus: NetworkStatus) {
    }
}
