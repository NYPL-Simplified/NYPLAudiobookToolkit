final class OpenAccessAudiobook: Audiobook {
    let player: Player
    var spine: [SpineElement]
    let uniqueIdentifier: String
    
    private var drmData: [String: Any]
    
    var drmStatus: DrmStatus {
        get {
            // Avoids force unwrapping
            // Should be save since the initializer should always set this value
            // Access to `drmData` is private and can only be modified by internal code
            return (drmData["status"] as? DrmStatus) ?? DrmStatus.succeeded
        }
        set(newStatus) {
            drmData["status"] = newStatus
            player.isDrmOk = newStatus == DrmStatus.succeeded
        }
    }
    
    public required init?(JSON: Any?) {
        drmData = [String: Any]()
        drmData["status"] = DrmStatus.succeeded
        guard let payload = JSON as? [String: Any],
        let metadata = payload["metadata"] as? [String: Any],
        let identifier = metadata["identifier"] as? String,
        let payloadSpine = ((payload["readingOrder"] as? [Any]) ?? (payload["spine"] as? [Any])) else {
            ATLog(.error, "OpenAccessAudiobook failed to init from JSON: \n\(JSON ?? "nil")")
            return nil
        }
        
        // Feedbook DRM Check
        if !FeedbookDRMProcessor.processManifest(payload, drmData: &drmData) {
            ATLog(.error, "FeedbookDRMProcessor failed to pass JSON: \n\(JSON ?? "nil")")
            return nil
        }
        
        let mappedSpine = payloadSpine.enumerated().compactMap { (tupleItem:(index: Int, element: Any)) -> OpenAccessSpineElement? in
            OpenAccessSpineElement(
                JSON: tupleItem.element,
                index: UInt(tupleItem.index),
                audiobookID: identifier
            )
            }.sorted {
                return $0.chapterNumber < $1.chapterNumber
            }
        if (mappedSpine.count == 0 || mappedSpine.count != payloadSpine.count) {
            ATLog(.error, "Failure to create any or all spine elements from the manifest.")
            return nil
        }
        self.spine = mappedSpine
        self.uniqueIdentifier = identifier
        guard let cursor = Cursor(data: self.spine) else {
            ATLog(.error, "Cursor could not be cast to Cursor<OpenAccessSpineElement>")
            return nil
        }
        self.player = OpenAccessPlayer(cursor: cursor, audiobookID: uniqueIdentifier, drmOk: (drmData["status"] as? DrmStatus) == DrmStatus.succeeded)
    }

    public func deleteLocalContent() {
        for element in self.spine {
            let task = element.downloadTask
            task.delete()
        }
    }
    
    public func checkDrmAsync() {
        FeedbookDRMProcessor.performAsyncDrm(book: self, drmData: drmData)
    }
}
