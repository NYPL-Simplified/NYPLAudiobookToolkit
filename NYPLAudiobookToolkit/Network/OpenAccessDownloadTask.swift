final class OpenAccessDownloadTask: DownloadTask {

    weak var delegate: DownloadTaskDelegate?

    var downloadProgress: Float {
        return 0
    }

    let key: String

    func fetch() {

    }

    func delete() {
    
    }

    public init(spineElement: SpineElement) {
        self.key = spineElement.key
    }
}
