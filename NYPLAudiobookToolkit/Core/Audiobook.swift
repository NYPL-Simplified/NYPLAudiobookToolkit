//
//  Audiobook.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

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
@objcMembers public final class AudiobookFactory: NSObject {
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
            let FindawayAudiobookClass = NSClassFromString("NYPLAEToolkit.FindawayAudiobook") as? Audiobook.Type
            audiobook = FindawayAudiobookClass?.init(JSON: JSON)
        default:
            audiobook = OpenAccessAudiobook(JSON: JSON)
        }
        return audiobook
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
        guard let spine = payload["readingOrder"] as? [Any] else { return nil }
        self.spine = spine.compactMap { (possibleLink) -> SpineElement? in
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
