enum OverdriveSpineElementMediaType: String {
    case audioMP3 = "audio/mp3"
}

final class OverdriveSpineElement: SpineElement {
    
    lazy var downloadTask: DownloadTask = {
        return OverdriveDownloadTask(spineElement: self)
    }()
    
    lazy var chapter: ChapterLocation = {
        return ChapterLocation(number: self.chapterNumber,
                               part: 0,
                               duration: self.duration,
                               startOffset: 0,
                               playheadOffset: 0,
                               title: self.title,
                               audiobookID: self.audiobookID)!
    }()
    
    let key: String
    let chapterNumber: UInt
    let title: String
    let url: URL
    let mediaType: OverdriveSpineElementMediaType
    let duration: TimeInterval
    let audiobookID: String
    
    public init?(JSON: Any?, index: UInt, audiobookID: String) {
        self.key = "\(audiobookID)-\(index)"
        self.chapterNumber = index
        self.title = "Part \(index + 1)"
        self.audiobookID = audiobookID
        
        guard let payload = JSON as? [String: Any],
        let urlString = payload["href"] as? String,
        let url = URL(string: urlString),
        let fileSize = payload["physicalFileLengthInBytes"] as? UInt else {
            ATLog(.error, "OverdriveSpineElement failed to init from JSON: \n\(JSON ?? "nil")")
            return nil
        }
        
        self.url = url
        self.mediaType = OverdriveSpineElementMediaType.audioMP3
        self.duration = estimatedDuration(from: fileSize)
    }
}

// With these assumptions on Overdrive MP3 audio file:
// 44100 hz, 8 bit, mono, 128 kbps
// Approx. 8000 byte/s
private func estimatedDuration(from size: UInt) -> TimeInterval {
    return Double(size) / 8000
}
