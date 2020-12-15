//
//  LCPSpineElement.swift
//  NYPLAudiobookToolkit
//
//  Created by Vladimir Fedorov on 19.11.2020.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import Foundation

enum LCPSpineElementMediaType: String {
    case audioMP3 = "audio/mp3"
    case audioAAC = "audio/aac"
    case audioMPEG = "audio/mpeg"
}

final class LCPSpineElement: SpineElement {
    
    /// Dictionary keys for localized `name` properties from `manifest.json`.
    ///
    /// `name` can be either a `String` or a dictionary with keys:
    /// - `value` for localized name
    /// - `language` for 2-letter country code
    enum LocalizedNameKeys: String {
        case value = "value"
        case language = "language"
    }
    
    /// Download task provides local decrypted file URL for further content management.
    lazy var downloadTask: DownloadTask = {
        return LCPDownloadTask(spineElement: self)
    }()
    
    lazy var chapter: ChapterLocation = {
        return ChapterLocation(
            number: self.chapterNumber,
            part: 0,
            duration: self.duration,
            startOffset: 0,
            playheadOffset: 0,
            title: self.title,
            audiobookID: self.audiobookID
            )!
    }()
    
    let key: String
    let chapterNumber: UInt
    let title: String
    let url: URL
    let mediaType: LCPSpineElementMediaType
    let duration: TimeInterval
    let audiobookID: String
    
    /// Spine element for LCP audiobooks
    /// - Parameters:
    ///   - JSON: JSON data for `readingOrder` element in audiobook `manifest.json` file.
    ///   - index: Element index in `readingOrder`.
    ///   - audiobookID: Audiobook identifier.
    init?(JSON: Any?, index: UInt, audiobookID: String) {
        self.key = "\(audiobookID)-\(index)"
        self.chapterNumber = index
        self.audiobookID = audiobookID
        
        guard let payload = JSON as? [String: Any],
            let urlString = payload["href"] as? String,
            let url = URL(string: urlString)
            else {
                ATLog(.error, "LCPSpineElement failed to init from JSON: \n\(JSON ?? "nil")")
                return nil
        }
        
        self.url = url
        let defaultTitleFormat = NSLocalizedString("Chapter %@", bundle: Bundle.audiobookToolkit()!, value: "Chapter %@", comment: "Default chapter title")
        let name = LCPSpineElement.elementName(JSON: payload["title"])
        self.title = name ?? String(format: defaultTitleFormat, "\(index + 1)")
        if let duration = payload["duration"] as? Double {
            self.duration = TimeInterval(duration)
        } else {
            self.duration = 0
        }
        if let encodingFormat = payload["encodingFormat"] as? String, let mediaType = LCPSpineElementMediaType(rawValue: encodingFormat) {
            self.mediaType = mediaType
        } else {
            self.mediaType = .audioMP3
        }
    }
    
    /// Title for a spine element from `name` parameter
    /// - Parameter JSON: `JSON` value for the `name` parameter; can be a string or an array of localized name dictionaries.
    /// - Returns: String value for `name` paramter or a localized name, if any found; a name matching "en" language code, if found; `nil` otherwise.
    private static func elementName(JSON: Any?) -> String? {
        if let stringName = JSON as? String {
            return stringName
        } else if let localizedNames = JSON as? [[String: String]] {
            return localizedName(localizedNames: localizedNames)
        }
        return nil
    }
    
    /// Localized name from the array of localizede names based on current application language code.
    /// - Parameter localizedNames: An array of localized name dictionaries,
    /// with `value` parameter containing the name and `language` parameter containing language code, for example:
    /// `[{"value":"Track 1", "language":"en"},{"value":"Piste 1", "language":"fr"}]`.
    /// - Returns: Localized name, if any found; name matching "en" language code, if found; `nil` otherwise.
    private static func localizedName(localizedNames: [[String: String]]) -> String? {
        let fallbackLanguageCode = "en"
        var fallbackName: String?
        let currentLanguageCode = Locale.autoupdatingCurrent.languageCode
        for localizedName in localizedNames {
            guard let languageCode = localizedName[LocalizedNameKeys.language.rawValue],
                let name = localizedName[LocalizedNameKeys.value.rawValue]
                else {
                    continue
            }
            if languageCode == fallbackLanguageCode {
                fallbackName = name
            }
            if let currentCode = currentLanguageCode, languageCode == currentCode {
                return name
            }
        }
        return fallbackName
    }
}
