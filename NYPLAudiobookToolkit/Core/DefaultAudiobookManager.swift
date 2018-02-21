//
//  AudiobookManager.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

@objc public protocol AudiobookNetworkServiceDelegate: class {
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement)
    func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didErrorFor spineElement: SpineElement)
}

@objc public protocol AudiobookNetworkService: class {
    func registerDelegate(_ delegate: AudiobookNetworkServiceDelegate)
    func removeDelegate(_ delegate: AudiobookNetworkServiceDelegate)
    func fetch()
    func fetchSpineAt(index: Int)
}

public final class DefaultAudiobookNetworkService: AudiobookNetworkService, DownloadTaskDelegate {
    private var delegates: NSHashTable<AudiobookNetworkServiceDelegate> = NSHashTable(options: [NSPointerFunctions.Options.weakMemory])
    
    public func registerDelegate(_ delegate: AudiobookNetworkServiceDelegate) {
        self.delegates.add(delegate)
    }
    
    public func removeDelegate(_ delegate: AudiobookNetworkServiceDelegate) {
        self.delegates.remove(delegate)
    }
    
    public func downloadTaskReadyForPlayback(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.delegates.allObjects.forEach({ (delegate) in
                delegate.audiobookNetworkService(self, didCompleteDownloadFor: spineElement)
            })
        }
    }

    public func downloadTaskDidUpdateDownloadPercentage(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.delegates.allObjects.forEach({ (delegate) in
                delegate.audiobookNetworkService(self, didUpdateDownloadPercentageFor: spineElement)
            })
        }
    }
    
    public func downloadTaskDidError(_ downloadTask: DownloadTask) {
        if let spineElement = self.spineElementByKey[downloadTask.key] {
            self.delegates.allObjects.forEach({ (delegate) in
                delegate.audiobookNetworkService(self, didErrorFor: spineElement)
            })
        }
    }
    
    let spine: [SpineElement]
    lazy var spineElementByKey: [String: SpineElement] = {
        var dict = [String: SpineElement]()
        self.spine.forEach { (element) in
            dict[element.downloadTask.key] = element
        }
        return dict
    }()

    public init(spine: [SpineElement]) {
        self.spine = spine
    }

    public func fetch() {
        self.spine.forEach { (element) in
            element.downloadTask.delegate = self
            element.downloadTask.fetch()
        }
    }
    
    public func fetchSpineAt(index: Int) {
        let downloadTask = self.spine[index].downloadTask
        downloadTask.delegate = self
        downloadTask.fetch()
    }
}

/// If the AudiobookManager runs into an error while fetching
/// values from the provided Audiobook, it may use this
/// protocol to request a new Audiobook from the host app.
@objc public protocol RefreshDelegate {

    /**
     Will be called when the manager determines it needs a new audiobook.
     
     Example usage:
     ```
     func updateAudiobook(completion: (Audiobook?) -> Void) {
     let audiobook = self.getAudiobook()
     completion(audiobook)
     }
     ```
     
     - Parameters:
        - completion: The block to be called when new audiobook has been obtained.
        - audiobook: The new Audiobook, may be nil if fetch was unsuccessful
     */
    func updateAudiobook(completion: (_ audiobook: Audiobook?) -> Void)
}

@objc public protocol AudiobookManagerDownloadDelegate {
    func audiobookManager(_ audiobookManager: AudiobookManager, didUpdateDownloadPercentageFor spineElement: SpineElement)
    func audiobookManager(_ audiobookManager: AudiobookManager, didBecomeReadyForPlayback spineElement: SpineElement)
    func audiobookManager(_ audiobookManager: AudiobookManager, didReceiveErrorFor spineElement: SpineElement)
}

@objc public protocol AudiobookManagerPlaybackDelegate {
    func audiobookManager(_ audiobookManager: AudiobookManager, didBeginPlaybackOf chapter: ChapterLocation)
    func audiobookManager(_ audiobookManager: AudiobookManager, didStopPlaybackOf chapter: ChapterLocation)
}

/// AudiobookManager is the main class for bringing Audiobook Playback to clients.
/// It is intended to be used by the host app to initiate downloads, control playback,
/// and manage the filesystem.
@objc public protocol AudiobookManager {
    weak var refreshDelegate: RefreshDelegate? { get set }
    weak var downloadDelegate: AudiobookManagerDownloadDelegate? { get set }
    weak var playbackDelegate: AudiobookManagerPlaybackDelegate? { get set }
    var metadata: AudiobookMetadata { get }
    var audiobook: Audiobook { get }
    var isPlaying: Bool { get }
    func fetch()
    func skipForward()
    func skipBack()
    func play()
    func pause()
    func updatePlaybackWith(_ chapter: ChapterLocation)
}

/// Implementation of the AudiobookManager intended for use by clients. Also intended
/// to be used by the AudibookDetailViewController to respond to UI events.
public class DefaultAudiobookManager: AudiobookManager {
    public weak var downloadDelegate: AudiobookManagerDownloadDelegate?
    public weak var playbackDelegate: AudiobookManagerPlaybackDelegate?
    public let metadata: AudiobookMetadata
    public let audiobook: Audiobook
    public var isPlaying: Bool {
        return self.player.isPlaying
    }

    private let player: Player
    private let networkService: AudiobookNetworkService
    public init (metadata: AudiobookMetadata, audiobook: Audiobook,  player: Player, networkService: AudiobookNetworkService) {
        self.metadata = metadata
        self.audiobook = audiobook
        self.player = player
        self.networkService = networkService
        
        self.player.delegate = self
        self.networkService.registerDelegate(self)
        
    }

    public convenience init (metadata: AudiobookMetadata, audiobook: Audiobook) {
        self.init(
            metadata: metadata,
            audiobook: audiobook,
            player: audiobook.player,
            networkService: DefaultAudiobookNetworkService(spine: audiobook.spine)
        )
    }
    
    weak public var refreshDelegate: RefreshDelegate?
    
    public func fetch() {
        self.networkService.fetch()
    }

    public func play() {
        self.player.play()
    }
    
    public func pause() {
        self.player.pause()
    }

    public func skipForward() {
        self.player.skipForward()
    }
    
    public func skipBack() {
        self.player.skipBack()
    }
    
    public func updatePlaybackWith(_ chapter: ChapterLocation) {
        self.player.jumpToLocation(chapter)
    }
}

extension DefaultAudiobookManager: AudiobookNetworkServiceDelegate {
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didCompleteDownloadFor spineElement: SpineElement) {
        self.downloadDelegate?.audiobookManager(self, didBecomeReadyForPlayback: spineElement)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didUpdateDownloadPercentageFor spineElement: SpineElement) {
        self.downloadDelegate?.audiobookManager(self, didUpdateDownloadPercentageFor: spineElement)
    }
    
    public func audiobookNetworkService(_ audiobookNetworkService: AudiobookNetworkService, didErrorFor spineElement: SpineElement) {
        self.downloadDelegate?.audiobookManager(self, didReceiveErrorFor: spineElement)
    }
    
    
}

extension DefaultAudiobookManager: PlayerDelegate {
    public func player(_ player: Player, didBeginPlaybackOf chapter: ChapterLocation) {
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.playbackDelegate?.audiobookManager(strongSelf, didBeginPlaybackOf: chapter)
            }
        }
    }

    public func player(_ player: Player, didStopPlaybackOf chapter: ChapterLocation) {
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.playbackDelegate?.audiobookManager(strongSelf, didStopPlaybackOf: chapter)
            }
        }
    }
}
