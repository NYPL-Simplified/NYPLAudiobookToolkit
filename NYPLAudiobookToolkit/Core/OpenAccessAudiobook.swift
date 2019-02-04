final class OpenAccessAudiobook: Audiobook {
    let player: Player
    var spine: [SpineElement]
    let uniqueIdentifier: String
    public func deleteLocalContent() {
        for element in self.spine {
            let task = element.downloadTask
            task.delete()
        }
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
            }.sorted {
                return $0.chapterNumber < $1.chapterNumber
            }
        if (mappedSpine.count == 0 || mappedSpine.count != payloadSpine.count) {
            ATLog(.error, "Failure to create any or all \"readingOrder\" spine elements from the manifest.")
            return nil
        }
        self.spine = mappedSpine
        self.uniqueIdentifier = identifier
        guard let cursor = Cursor(data: self.spine) else {
            ATLog(.error, "Cursor could not be cast to Cursor<OpenAccessSpineElement>")
            return nil
        }
        self.player = OpenAccessPlayer(cursor: cursor, audiobookID: uniqueIdentifier)
    }
}
