//
//  Audiobook.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

@objc public enum DrmStatus:Int {
    public typealias RawValue = Int
    case failed
    case processing
    case succeeded
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
    var drmStatus: DrmStatus { get set }
    func checkDrmAsync()
    func deleteLocalContent()
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
        let audiobook: Audiobook?
        if let scheme = possibleScheme {
            switch scheme {
            case "http://librarysimplified.org/terms/drm/scheme/FAE":
                let FindawayAudiobookClass = NSClassFromString("NYPLAEToolkit.FindawayAudiobook") as? Audiobook.Type
                audiobook = FindawayAudiobookClass?.init(JSON: JSON)
            default:
                audiobook = OpenAccessAudiobook(JSON: JSON)
            }
        } else {
            audiobook = OpenAccessAudiobook(JSON: JSON)
        }
        ATLog(.debug, "checkDrmAsync")
        audiobook?.checkDrmAsync()
        return audiobook
    }
}
