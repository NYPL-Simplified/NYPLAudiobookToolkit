final class OverdriveAudiobook: Audiobook {
    let uniqueIdentifier: String
    
    var spine: [SpineElement]
    
    let player: Player
    
    var drmStatus: DrmStatus {
        get {
            return DrmStatus.succeeded
        }
        set(newStatus) {
            player.isDrmOk = newStatus == DrmStatus.succeeded
        }
    }
    
    public required init?(JSON: Any?) {
        guard let payload = JSON as? [String: Any],
        let identifier = payload["id"] as? String,
        let links = payload["links"] as? [String: Any],
        let payloadSpine = links["contentlinks"] as? [[String: Any]] else {
            ATLog(.error, "OverdriveAudiobook failed to init from JSON: \n\(JSON ?? "nil")")
            return nil
        }
        
        var mappedSpine = [OverdriveSpineElement]()
        
        for (index, spineDict) in payloadSpine.enumerated() {
            if let spineElement = OverdriveSpineElement(JSON: spineDict, index: UInt(index), audiobookID: identifier) {
                mappedSpine.append(spineElement)
            }
        }
        
        mappedSpine.sort { (x, y) -> Bool in
            return x.chapterNumber < y.chapterNumber
        }
        
        if (mappedSpine.count == 0 || mappedSpine.count != payloadSpine.count) {
            ATLog(.error, "Failure to create any or all spine elements from the manifest.")
            return nil
        }
        self.spine = mappedSpine
        self.uniqueIdentifier = identifier
        
        guard let cursor = Cursor(data: self.spine) else {
            ATLog(.error, "Cursor could not be cast to Cursor<OverdriveSpineElement>")
            return nil
        }
        
        self.player = OverdrivePlayer(cursor: cursor, audiobookID: uniqueIdentifier, drmOk: true)
    }
    
    func checkDrmAsync() {
        // No DRM for Overdrive
    }
    
    func deleteLocalContent() {
        for element in self.spine {
            let task = element.downloadTask
            task.delete()
        }
    }
}
