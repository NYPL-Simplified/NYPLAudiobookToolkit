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
    init?(JSON: Any?)
}

/// Host app should instantiate a manifest object with JSON.
/// This manifest should then be able to construct utility classes
/// using data in the spine of that JSON.
@objc public class DefaultManifest: NSObject, Manifest {
    public var downloadTask: DownloadTask {
        return self.manifest.downloadTask
    }
    private let manifest: Manifest
    public required init?(JSON: Any?) {
        // Instead of doing this wonkyness - we are going to try and have a
        // `content-type` field in the manifest which dictates how the client should
        // attempt to aquire the files. These content types will map to Manifest classes
        // that the DefaultManifest will instantiate. If no content type is provided,
        // then OpenAccessManifest will be attempted.
        let possibleManifest = [ FindawayManifest.self, OpenAccessManifest.self].flatMap { (manifestClass: Manifest.Type) -> Manifest? in
            manifestClass.init(JSON: JSON)
        }.first
        guard let realManifest = possibleManifest else { return nil }
        self.manifest = realManifest
        super.init()
        
    }
}

private class FindawayManifest: Manifest {
    let downloadTask: DownloadTask
    
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
        guard !self.spine.isEmpty else { return nil }
        self.downloadTask = FindawayDownloadTask(spine: self.spine)
    }
}


private class OpenAccessManifest: Manifest {
    let downloadTask: DownloadTask
    
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

    public init?(JSON: Any?, sessionKey: String, audiobookID: String, licenseID: String) {
        guard let payload = JSON as? [String: Any] else { return nil }
        guard let sequence = payload[findawayKey("sequence")] as? UInt else { return nil }
        guard let partNumber = payload[findawayKey("part")] as? UInt else { return nil }
        self.licenseID = licenseID
        self.chapterNumber = sequence
        self.partNumber = partNumber
        self.sessionKey = sessionKey
        self.audiobookID = audiobookID
    }
}
