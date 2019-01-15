final class OpenAccessSpineElement: SpineElement {
    var key: String {
        return self.url.absoluteString
    }

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

    let chapterNumber: UInt
    let title: String
    let url: URL
    let mediaType: String
    let duration: TimeInterval
    let audiobookID: String

    public init?(JSON: Any?, index: UInt, audiobookID: String) {
        guard let payload = JSON as? [String: Any],
            let title = payload["title"] as? String,
            let urlString = payload["href"] as? String,
            let url = URL(string: urlString),
            let mediaType = payload["type"] as? String,
            let duration = payload["duration"] as? TimeInterval else {
                ATLog(.error, "OpenAccessSpineElement failed to init from JSON: \n\(JSON ?? "nil")")
                return nil
        }
        self.title = title
        self.url = url
        self.mediaType = mediaType
        self.duration = duration
        self.chapterNumber = index
        self.audiobookID = audiobookID
    }
}
