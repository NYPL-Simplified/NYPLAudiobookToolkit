//
//  AudiobookTableOfContents.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 1/22/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import NYPLUtilitiesObjc

protocol AudiobookTableOfContentsProviding {
  var tocCount: Int { get }
  var delegate: AudiobookTableOfContentsUpdating? { get set }
  
  func currentSpineIndex() -> Int?
  func spineElement(for index: Int) -> SpineElement?
  func spineIndex(for chapterLocation: ChapterLocation) -> Int?
}

protocol AudiobookTableOfContentsUpdating: AnyObject {
  func audiobookTableOfContentsDidUpdate(for chapterLocation: ChapterLocation?)
}

/// This class connects the audio player and network service to provide table of contents data
/// through the `AudiobookTableOfContentsProviding` protocol.
public final class AudiobookTableOfContents: NSObject, AudiobookTableOfContentsProviding {
    
    public var downloadProgress: Float {
        return self.networkService.downloadProgress
    }
  
    var tocCount: Int {
        return self.networkService.spine.count
    }

    /// Download all available files from network for the current audiobook.
    public func fetch() {
        self.networkService.fetch()
    }

    /// Delete all available files for the current audiobook.
    public func deleteAll() {
        self.networkService.deleteAll()
    }

    weak var delegate: AudiobookTableOfContentsUpdating?
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
  
    func spineElement(for index: Int) -> SpineElement? {
      guard index >= 0 && tocCount > index else {
        return nil
      }
      
      return self.networkService.spine[index]
    }
  
    func spineIndex(for chapterLocation: ChapterLocation) -> Int? {
      return networkService.spine.firstIndex{ $0.chapter == chapterLocation }
    }
}

extension AudiobookTableOfContents: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDidUpdate(for: chapter)
    }
    
    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        self.delegate?.audiobookTableOfContentsDidUpdate(for: chapter)
    }

    public func player(_ player: Player, didFailPlaybackOf chapter: ChapterLocation, withError error: NSError?) { }
    public func player(_ player: Player, didComplete chapter: ChapterLocation) { }
    public func playerDidUnload(_ player: Player) { }
}

extension AudiobookTableOfContents: AudiobookNetworkServiceDelegate {
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didReceive error: NSError?, for spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDidUpdate(for: spineElement.chapter)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didCompleteDownloadFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDidUpdate(for: spineElement.chapter)
    }

    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didUpdateProgressFor spineElement: SpineElement)
    {
        self.delegate?.audiobookTableOfContentsDidUpdate(for: spineElement.chapter)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didDeleteFileFor spineElement: SpineElement) {
        self.delegate?.audiobookTableOfContentsDidUpdate(for: spineElement.chapter)
    }

    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didUpdateOverallDownloadProgress progress: Float) {
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        didTimeoutFor spineElement: SpineElement?,
                                        networkStatus: NetworkStatus) {
        self.delegate?.audiobookTableOfContentsDidUpdate(for: spineElement?.chapter)
    }
  
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService,
                                        downloadExceededTimeLimitFor spineElement: SpineElement,
                                        elapsedTime: TimeInterval,
                                        networkStatus: NetworkStatus) {
    }
}
