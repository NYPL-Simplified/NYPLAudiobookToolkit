final class OpenAccessAudiobook: Audiobook {
    let player: Player
    var spine: [SpineElement]
    let uniqueIdentifier: String
    public func deleteLocalContent() {
        // TODO
        // GODO TODO what was Dean intending here? Is it implemented in FindawayAudiobook?
        // I suppose I could delete the directory in /caches that the audio files are saved in
    }
    public required init?(JSON: Any?) {
        guard let payload = JSON as? [String: Any],
        let metadata = payload["metadata"] as? [String: Any],
        let identifier = metadata["identifier"] as? String,
        let payloadSpine = payload["readingOrder"] as? [Any] else {
            ATLog(.error, "OpenAccessAudiobook failed to init from JSON: \n\(JSON ?? "nil")")
            return nil
        }
        let mappedSpine = payloadSpine.enumerated().compactMap { (tupleItem:(index: Int, element: Any)) -> OpenAccessSpineElement? in
            OpenAccessSpineElement(
                JSON: tupleItem.element,
                index: UInt(tupleItem.index),
                audiobookID: identifier
            )
        }
        if (mappedSpine.count == 0 || mappedSpine.count != payloadSpine.count) {
            ATLog(.error, "Failure to create all \"readingOrder\" spine elements from the manifest.")
            return nil
        }
        self.spine = mappedSpine
        self.uniqueIdentifier = identifier
        guard let cursor = Cursor(data: self.spine) else { return nil }
        self.player = OpenAccessPlayer(cursor: cursor, audiobookID: uniqueIdentifier)
    }
}
