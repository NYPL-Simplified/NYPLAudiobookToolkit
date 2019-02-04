final class OpenAccessDownloadTask: DownloadTask {

    public enum AssetResult {
        /// The file exists at the given URL.
        case saved(URL)
        /// The file is missing at the given URL.
        case missing(URL)
        /// Could not create a valid URL to check.
        case unknown
    }

    private let DownloadTaskTimeoutValue = 60.0

    weak var delegate: DownloadTaskDelegate?

    /// Progress should be set to 1 if the file already exists.
    var downloadProgress: Float = 0 {
        didSet {
            self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
        }
    }

    let key: String
    let url: URL
    let urlMediaType: OpenAccessSpineElementMediaType
    let alternateLinks: [(OpenAccessSpineElementMediaType, URL)]?

    public init(spineElement: OpenAccessSpineElement) {
        self.key = spineElement.key
        self.url = spineElement.url
        self.urlMediaType = spineElement.mediaType
        self.alternateLinks = spineElement.alternateUrls
    }

    /// If the asset is already downloaded and verified, return immediately and
    /// update state to the delegates. Otherwise, attempt to download the file
    /// referenced in the spine element.
    func fetch() {
        switch self.assetFileStatus() {
        case .saved(_):
            downloadProgress = 1.0
            self.delegate?.downloadTaskReadyForPlayback(self)
        case .missing(let missingAssetURL):
            switch urlMediaType {
            case .rbDigital:
                self.downloadAssetForRBDigital(toLocalDirectory: missingAssetURL)
            case .audioMPEG:
                self.downloadAsset(fromRemoteURL: self.url, toLocalDirectory: missingAssetURL)
            }
        case .unknown:
            self.delegate?.downloadTaskFailed(self, withError: nil)
        }
    }

    func delete() {
        switch assetFileStatus() {
        case .saved(let url):
            do {
                try FileManager.default.removeItem(at: url)
                self.delegate?.downloadTaskDidDeleteAsset(self)
            } catch {
                ATLog(.error, "FileManager removeItem error:\n\(error)")
            }
        default:
            ATLog(.error, "No file located at directory to delete.")
        }
    }

    public func assetFileStatus() -> AssetResult {
        guard let localAssetURL = localDirectory() else {
            return AssetResult.unknown
        }
        if FileManager.default.fileExists(atPath: localAssetURL.path) {
            return AssetResult.saved(localAssetURL)
        } else {
            return AssetResult.missing(localAssetURL)
        }
    }

    /// Directory of the downloaded file.
    private func localDirectory() -> URL? {
        let fileManager = FileManager.default
        let cacheDirectories = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDirectory = cacheDirectories.first else {
            ATLog(.error, "Could not find caches directory.")
            return nil
        }
        guard let filename = hash(self.key) else {
            ATLog(.error, "Could not create a valid hash from download task ID.")
            return nil
        }
        return cacheDirectory.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("mp3")
    }

    /// RBDigital media types first download an intermediate document, which points
    /// to the url of the actual asset to download.
    private func downloadAssetForRBDigital(toLocalDirectory localURL: URL) {

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in

            guard let data = data,
                let response = response,
                (error == nil) else {
                ATLog(.error, "Network request failed for RBDigital partial file. Error: \(error!.localizedDescription)")
                return
            }

            if (response as? HTTPURLResponse)?.statusCode == 200 {
                do {
                    if let responseBody = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any],
                        let typeString = responseBody["type"] as? String,
                        let mediaType = OpenAccessSpineElementMediaType(rawValue: typeString),
                        let urlString = responseBody["url"] as? String,
                        let assetUrl = URL(string: urlString) {

                        switch mediaType {
                        case .audioMPEG:
                            self.downloadAsset(fromRemoteURL: assetUrl, toLocalDirectory: localURL)
                        case .rbDigital:
                            ATLog(.error, "Wrong media type for download task.")
                        }
                    } else {
                        ATLog(.error, "Invalid or missing property in JSON response to download task.")
                    }
                } catch {
                    ATLog(.error, "Error deserializing JSON in download task.")
                }
            } else {
                ATLog(.error, "Failed with server response: \n\(response.description)")
            }
        }
        task.resume()
    }

    private func downloadAsset(fromRemoteURL remoteURL: URL, toLocalDirectory: URL) {

        let config = URLSessionConfiguration.ephemeral
        let delegate = OpenAccessDownloadTaskURLSessionDelegate(downloadTask: self, delegate: self.delegate)
        let session = URLSession(configuration: config,
                                 delegate: delegate,
                                 delegateQueue: OperationQueue.main)

        let request = URLRequest(url: remoteURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: DownloadTaskTimeoutValue)

        let task = session.downloadTask(with: request) { (fileURL, response, error) in

            guard let fileURL = fileURL, let response = response else {
                if let error = error {
                    ATLog(.error, "No file URL or response from download task: \(self.key).", error: error)
                } else {
                    ATLog(.error, "No file URL or response from download task: \(self.key)")
                }
                self.delegate?.downloadTaskFailed(self, withError: error as NSError?)
                return
            }

            let httpResponse = response as? HTTPURLResponse
            if ((error == nil) && (httpResponse?.statusCode == 200)) {

                let fileManager = FileManager.default
                do {
                    try fileManager.moveItem(at: fileURL, to: toLocalDirectory)
                    ATLog(.debug, "File successfully downloaded and moved to: \(toLocalDirectory)")
                    self.downloadProgress = 1.0
                    self.delegate?.downloadTaskReadyForPlayback(self)
                }
                catch let error as NSError {
                    ATLog(.error, "FileManager removeItem error:\n\(error)")
                    self.downloadProgress = 0.0
                    self.delegate?.downloadTaskFailed(self, withError: nil)
                    return
                }
            }
            else {
                ATLog(.error, "Download Task failed with server response: \n\(httpResponse?.description ?? "nil")", error: error)
                self.downloadProgress = 0.0
                self.delegate?.downloadTaskFailed(self, withError: nil)
                return
            }

        }
        task.resume()
    }

    private func hash(_ key: String) -> String? {
        guard let hash = NYPLStringAdditions.sha256forString(key) else {
            return nil
        }
        return hash
    }
}

final class OpenAccessDownloadTaskURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {

    private let downloadTask: OpenAccessDownloadTask
    private let delegate: DownloadTaskDelegate?

    required init(downloadTask: OpenAccessDownloadTask, delegate: DownloadTaskDelegate?) {
        self.downloadTask = downloadTask
        self.delegate = delegate
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in completion block..
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            ATLog(.error, "No file URL or response from download task: \(self.downloadTask.key).", error: error)
        } else {
            ATLog(.error, "No file URL or response from download task: \(self.downloadTask.key)")
        }
        self.delegate?.downloadTaskFailed(self.downloadTask, withError: error as NSError?)
        return
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64)
    {

        debugPrint("totalWritten: \(totalBytesWritten). expectedToWrite: \(totalBytesExpectedToWrite)")

        if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) ||
            totalBytesExpectedToWrite == 0 {
            self.downloadTask.downloadProgress = 0.0
        }

        if totalBytesWritten >= totalBytesExpectedToWrite {
            self.downloadTask.downloadProgress = 1.0
        } else if totalBytesWritten <= 0 {
            self.downloadTask.downloadProgress = 0.0
        } else {
            self.downloadTask.downloadProgress = Float(totalBytesWritten / totalBytesExpectedToWrite)
        }

        self.delegate?.downloadTaskDidUpdateDownloadPercentage(self.downloadTask)
    }
}
