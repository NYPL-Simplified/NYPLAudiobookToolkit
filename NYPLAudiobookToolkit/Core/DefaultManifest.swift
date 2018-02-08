//
//  AudiobookManifest.swift
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

@objc public protocol Manifest: class {
    var downloadTask: DownloadTask { get }
    var player: Player { get }
    init?(JSON: Any?)
}

/// Host app should instantiate a manifest object with JSON.
/// This manifest should then be able to construct utility classes
/// using data in the spine of that JSON.
@objc public class DefaultManifest: NSObject, Manifest {
    public var player: Player {
        return self.manifest.player
    }
    
    public var downloadTask: DownloadTask {
        return self.manifest.downloadTask
    }
    private let manifest: Manifest
    private static let manifestConstructorsByContentType: [String: Manifest.Type] = [
        "http://www.librarysimplified.org/terms/drm/scheme/FAE" : FindawayManifest.self,
    ]

    public required init?(JSON: Any?) {
        guard let JSON = JSON as? [String: Any] else { return nil }
        let drm = JSON["drm:type"] as? [String: Any]
        let scheme = drm?["drm:scheme"] as? String
        let manifestConstructor = DefaultManifest.constructorForContentType(scheme)
        guard let realManifest = manifestConstructor.init(JSON: JSON) else { return nil }
        self.manifest = realManifest
        super.init()
    }

    static func constructorForContentType(_ contentType: String?) -> Manifest.Type {
        var constructor: Manifest.Type = OpenAccessManifest.self
        guard let contentType = contentType else { return constructor }
        if let specifiedConstructor = self.manifestConstructorsByContentType[contentType] {
            constructor = specifiedConstructor
        }
        return constructor
    }
}

private class FindawayManifest: Manifest {
    let downloadTask: DownloadTask
    let player: Player
    private let spine: [FindawayFragment]
    public required init?(JSON: Any?) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let metadata = payload["metadata"] as? [String: Any] else { return nil }
        guard let spine = payload["spine"] as? [Any] else { return nil }
        guard let sessionKey = metadata[findawayKey("sessionKey")] as? String else { return nil }
        guard let audiobookID = metadata[findawayKey("fulfillmentId")] as? String else { return nil }
        guard let licenseID = metadata[findawayKey("licenseId")] as? String else { return nil }
        self.spine = spine.flatMap { (possibleLink) -> FindawayFragment? in
            FindawayFragment(
                JSON: possibleLink,
                sessionKey: sessionKey,
                audiobookID: audiobookID,
                licenseID: licenseID
            )
        }
        guard let firstFragment = self.spine.first else { return nil }
        self.downloadTask = FindawayDownloadTask(spine: self.spine)
        self.player = FindawayPlayer(spine: self.spine, fragment: firstFragment)
    }
}


private class OpenAccessManifest: Manifest {
    let downloadTask: DownloadTask
    let player: Player
    private let spine: [OpenAccessFragment]
    public required init?(JSON: Any?) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let spine = payload["spine"] as? [Any] else { return nil }
        self.spine = spine.flatMap { (possibleLink) -> OpenAccessFragment? in
            OpenAccessFragment(
                JSON: possibleLink
            )
        }
        guard !self.spine.isEmpty else { return nil }
        self.downloadTask = OpenAccessDownloadTask(spine: self.spine)
        self.player = OpenAccessPlayer(spine: self.spine)
    }
}

class OpenAccessFragment: NSObject {
    let url: URL
    let mediaType: String
    let duration: Int
    let bitrate: Int

    public init?(JSON: Any?) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let address = payload["href"] as? String else { return nil }
        guard let url = URL(string: address) else { return nil }
        guard let mediaType = payload["type"] as? String else { return nil }
        guard let duration = payload["duration"] as? Int else { return nil }
        guard let bitrate = payload["bitrate"] as? Int else { return nil }
        self.url = url
        self.mediaType = mediaType
        self.duration = duration
        self.bitrate = bitrate
    }
}

class FindawayFragment: NSObject {
    let chapterNumber: UInt
    let partNumber: UInt
    let sessionKey: String
    let audiobookID: String
    let licenseID: String
    let duration: TimeInterval?

    public init?(JSON: Any?, sessionKey: String, audiobookID: String, licenseID: String) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let sequence = payload[findawayKey("sequence")] as? UInt else { return nil }
        guard let partNumber = payload[findawayKey("part")] as? UInt else { return nil }
        self.licenseID = licenseID
        self.chapterNumber = sequence
        self.partNumber = partNumber
        self.sessionKey = sessionKey
        self.audiobookID = audiobookID
        self.duration = payload["duration"] as? TimeInterval
    }
}
