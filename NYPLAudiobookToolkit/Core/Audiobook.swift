//
//  Audiobook.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AudioEngine

private func findawayKey(_ key: String) -> String {
    return "findaway:\(key)"
}

@objc public protocol SpineElement: class {
    var key: String { get }
    var downloadTask: DownloadTask { get }
    var chapter: ChapterLocation { get }
}

@objc public protocol Audiobook: class {
    var uniqueIdentifier: String { get }
    var spine: [SpineElement] { get }
    var player: Player { get }
    init?(JSON: Any?)
}

/// Host app should instantiate a audiobook object with JSON.
/// This audiobook should then be able to construct utility classes
/// using data in the spine of that JSON.
@objc public final class AudiobookFactory: NSObject {
    public static func audiobook(_ JSON: Any?) -> Audiobook? {
        guard let JSON = JSON as? [String: Any] else { return nil }
        let metadata = JSON["metadata"] as? [String: Any]
        let drm = metadata?["encrypted"] as? [String: Any]
        let possibleScheme = drm?["scheme"] as? String
        guard let scheme = possibleScheme else {
            return OpenAccessAudiobook(JSON: JSON)
        }

        let audiobook: Audiobook?
        switch scheme {
        case "http://librarysimplified.org/terms/drm/scheme/FAE":
            audiobook = FindawayAudiobook(JSON: JSON)
        default:
            audiobook = OpenAccessAudiobook(JSON: JSON)
        }
        return audiobook
    }
}

private final class FindawayAudiobook: Audiobook {
    let player: Player
    let spine: [SpineElement]
    let uniqueIdentifier: String
    public required init?(JSON: Any?) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let metadata = payload["metadata"] as? [String: Any] else { return nil }
        guard let encrypted = metadata["encrypted"] as? [String: Any] else { return nil }
        guard let spine = payload["spine"] as? [Any] else { return nil }
        guard let sessionKey = encrypted[findawayKey("sessionKey")] as? String else { return nil }
        guard let audiobookID = encrypted[findawayKey("fulfillmentId")] as? String else { return nil }
        guard let licenseID = encrypted[findawayKey("licenseId")] as? String else { return nil }
        self.spine = spine.flatMap { (possibleLink) -> SpineElement? in
            FindawaySpineElement(
                JSON: possibleLink,
                sessionKey: sessionKey,
                audiobookID: audiobookID,
                licenseID: licenseID
            )
        }
        guard let firstSpineElement = self.spine.first as? FindawaySpineElement else { return nil }
        guard let cursor = Cursor(data: self.spine) else { return nil }
        self.uniqueIdentifier = audiobookID
        self.player = FindawayPlayer(spineElement: firstSpineElement, cursor: cursor)
    }
}

final class FindawaySpineElement: SpineElement {
    var key: String {
        return "FAEAudioEngine-\(self.audiobookID)-\(self.chapterNumber)-\(self.partNumber)"
    }
    
    lazy var downloadTask: DownloadTask = {
        return FindawayDownloadTask(spineElement: self)
    }()
    
    lazy var chapter: ChapterLocation = {
        return ChapterLocation(
            number: self.chapterNumber,
            part: self.partNumber,
            duration: self.duration,
            startOffset: 0,
            playheadOffset: 0,
            title: self.title,
            audiobookID: self.audiobookID
        )!
    }()
    
    let chapterNumber: UInt
    let partNumber: UInt
    let sessionKey: String
    let audiobookID: String
    let licenseID: String
    let duration: TimeInterval
    let title: String?
    
    public init?(JSON: Any?, sessionKey: String, audiobookID: String, licenseID: String) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let sequence = payload[findawayKey("sequence")] as? UInt else { return nil }
        guard let partNumber = payload[findawayKey("part")] as? UInt else { return nil }
        guard let duration = payload["duration"] as? TimeInterval else { return nil }
        self.title = payload["title"] as? String
        self.licenseID = licenseID
        self.chapterNumber = sequence
        self.partNumber = partNumber
        self.sessionKey = sessionKey
        self.audiobookID = audiobookID
        self.duration = duration
    }
    
    
}

private final class OpenAccessAudiobook: Audiobook {
    let player: Player
    var spine: [SpineElement]
    let uniqueIdentifier: String
    public required init?(JSON: Any?) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let metadata = payload["metadata"] as? [String: Any] else { return nil }
        guard let identifier = metadata["identifier"] as? String else { return nil }
        guard let spine = payload["spine"] as? [Any] else { return nil }
        self.spine = spine.flatMap { (possibleLink) -> SpineElement? in
            OpenAccessSpineElement(
                JSON: possibleLink,
                audiobookID: identifier
            )
        }
        guard !self.spine.isEmpty else { return nil }
        self.uniqueIdentifier = identifier
        self.player = OpenAccessPlayer()
    }
}


final class OpenAccessSpineElement: SpineElement {
    let url: URL
    let mediaType: String
    let duration: TimeInterval
    let bitrate: Int
    let audiobookID: String
    var key: String {
        return self.url.absoluteString
    }
    
    lazy var downloadTask: DownloadTask = {
        return OpenAccessDownloadTask(spineElement: self)
    }()
    
    lazy var chapter: ChapterLocation = {
        return ChapterLocation(
            number: 0,
            part: 0,
            duration: self.duration,
            startOffset: 0,
            playheadOffset: 0,
            title: nil,
            audiobookID: self.audiobookID
        )!
    }()


    public init?(JSON: Any?, audiobookID: String) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let address = payload["href"] as? String else { return nil }
        guard let url = URL(string: address) else { return nil }
        guard let mediaType = payload["type"] as? String else { return nil }
        guard let duration = payload["duration"] as? TimeInterval else { return nil }
        guard let bitrate = payload["bitrate"] as? Int else { return nil }
        self.url = url
        self.mediaType = mediaType
        self.duration = duration
        self.bitrate = bitrate
        self.audiobookID = audiobookID
    }
}
