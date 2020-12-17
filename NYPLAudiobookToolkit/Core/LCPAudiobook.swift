//
//  LCPAudiobook.swift
//  NYPLAudiobookToolkit
//
//  Created by Vladimir Fedorov on 19.11.2020.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import Foundation

@objc public class LCPAudiobook: NSObject, Audiobook {
    
    /// Readium @context parameter value for LCP audiobooks
    static let manifestContext = "http://readium.org/webpub-manifest/context.jsonld"
    
    public var uniqueIdentifier: String
    
    public var spine: [SpineElement]
    
    public var player: Player
    
    public var drmStatus: DrmStatus {
        get {
            return DrmStatus.succeeded
        }
        set(newStatus) {
            player.isDrmOk = newStatus == DrmStatus.succeeded
        }
    }
    
    public func checkDrmAsync() {
        // We don't check DRM status here;
        // LCP library checks it accessing files
    }
    
    public func deleteLocalContent() {
        for spineElement in spine {
            spineElement.downloadTask.delete()
        }
    }
    
    @available(*, deprecated, message: "Use init?(JSON: Any?, decryptor: DRMDecryptor?) instead")
    public required convenience init?(JSON: Any?) {
        self.init(JSON: JSON, decryptor: nil)
    }
    
    /// LCP DRM protected audiobook
    /// - Parameters:
    ///   - JSON: Dictionary with audiobook and spine elements data from `manifest.json`.
    ///   - decryptor: LCP DRM decryptor.
    init?(JSON: Any?, decryptor: DRMDecryptor?) {
        guard let publication = JSON as? [String: Any],
            let metadata = publication["metadata"] as? [String: Any],
            let id = metadata["identifier"] as? String,
            let resources = publication["readingOrder"] as? [[String: Any]]
            else {
                ATLog(.error, "LCPAudiobook failed to init from JSON: \n\(JSON ?? "nil")")
                return nil
            }
        self.uniqueIdentifier = id
        var spineElements: [LCPSpineElement] = []
        for (index, resource) in resources.enumerated() {
            if let spineElement = LCPSpineElement(JSON: resource, index: UInt(index), audiobookID: uniqueIdentifier) {
                spineElements.append(spineElement)
            }
        }
        spineElements.sort { (a, b) -> Bool in
            a.chapterNumber < b.chapterNumber
        }
        self.spine = spineElements
        guard let cursor = Cursor(data: spine) else {
            let title = metadata["title"] as? String ?? ""
            ATLog(.error, "Cursor could not be cast to Cursor<LCPSpineElement> in \(id) \(title)")
            return nil
        }
        player = LCPPlayer(cursor: cursor, audiobookID: uniqueIdentifier, decryptor: decryptor)
    }
}
