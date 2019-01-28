enum OpenAccessSpineElementMediaType: String {
    case audioMPEG = "audio/mpeg"
    case rbDigital = "vnd.librarysimplified/rbdigital-access-document+json"
}

final class OpenAccessSpineElement: SpineElement {

    lazy var downloadTask: DownloadTask = {
        return OpenAccessDownloadTask(spineElement: self)
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
    let alternateUrls: [(OpenAccessSpineElementMediaType, URL)]?
    let mediaType: OpenAccessSpineElementMediaType
    let duration: TimeInterval
    let audiobookID: String

    public init?(JSON: Any?, index: UInt, audiobookID: String) {
        self.key = "\(audiobookID)-\(index)"
        self.chapterNumber = index
        self.audiobookID = audiobookID

        guard let payload = JSON as? [String: Any],
            let title = payload["title"] as? String,
            let urlString = payload["href"] as? String,
            let url = URL(string: urlString),
            let duration = payload["duration"] as? TimeInterval else {
                ATLog(.error, "OpenAccessSpineElement failed to init from JSON: \n\(JSON ?? "nil")")
                return nil
        }
        self.title = title
        self.url = url
        self.duration = duration

        guard let mediaTypeString = payload["type"] as? String,
            let mediaType = OpenAccessSpineElementMediaType(rawValue: mediaTypeString) else {
                ATLog(.error, "Media Type of open acess spine element not supported.")
                return nil
        }
        self.mediaType = mediaType

        let alternatesJson = payload["alternates"] as? [[String:String]]
        self.alternateUrls = OpenAccessSpineElement.parseAlternateUrls(alternatesJson)
    }

    private class func parseAlternateUrls(_ json: [[String:String]]?) -> [(OpenAccessSpineElementMediaType, URL)]? {
        guard let json = json else {
            ATLog(.debug, "No alternate links provided in spine.")
            return nil
        }
        let alternates = json.compactMap({ (alternateLink) -> (OpenAccessSpineElementMediaType, URL)? in
            if let typeString = alternateLink["type"],
                let mediaType = OpenAccessSpineElementMediaType(rawValue: typeString),
                let urlString = alternateLink["href"],
                let url = URL(string: urlString) {
                return (mediaType, url)
            } else {
                ATLog(.error, "Invalid alternate type/href thrown out: \n\(alternateLink)")
                return nil
            }
        })
        if alternates.count >= 1 {
            return alternates
        } else {
            return nil
        }
    }
}
