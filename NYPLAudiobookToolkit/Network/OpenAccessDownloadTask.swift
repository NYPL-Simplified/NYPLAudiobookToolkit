final class OpenAccessDownloadTask: DownloadTask {

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

    //GODO TODO shouldn't delegate be in the init here, rather than added as a property later?
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

        guard let localAssetURL = localDirectory() else {
            //GODO TODO consider adding progress = 0 even though it's technically covered elsewhere
            self.delegate?.downloadTaskFailed(self, withError: nil)
            return
        }

        if FileManager.default.fileExists(atPath: localAssetURL.path) {
            downloadProgress = 1.0
            self.delegate?.downloadTaskReadyForPlayback(self)
            return
        }

        switch urlMediaType {
        case .rbDigital:
            downloadAssetForRBDigital(toLocalDirectory: localAssetURL)
        case .audioMPEG:
            downloadAsset(fromRemoteURL: self.url, toLocalDirectory: localAssetURL)
        }
    }

    //GODO TODO make sure to surface this somewhere in the UI so the user can at least
    //delete something that try again without having to sign out/in
    func delete() {

        //GODO TODO
      
    }

    public func localDirectory() -> URL? {
        let fileManager = FileManager.default
        let cacheDirectories = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDirectory = cacheDirectories.first else {
            ATLog(.error, "Could not find caches directory.")
            return nil
        }
        let hashedKey = hash(self.key)
        guard let key = hashedKey else {
            ATLog(.error, "Could not create a valid hash from download task ID.")
            return nil
        }
        return cacheDirectory.appendingPathComponent("\(key)", isDirectory: false).appendingPathExtension("mp3")
    }

    //GODO TODO remember to add a method to delete all cached content, which could be called by a host when a user is signing out

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
        //GODO TODO find a way to get a shared session out of each individual download task, perhaps in the manager or network service
        //OR just use the default shared session instead of a custom one, but maybe I can't have a delegate if I do that.
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config,
                                 delegate: OpenAccessDownloadTaskURLSessionDelegate(downloadTask: self, delegate: self.delegate),
                                 delegateQueue: OperationQueue.main)

        let request = URLRequest(url: remoteURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: DownloadTaskTimeoutValue)

        let task = session.downloadTask(with: request) { (fileURL, response, error) in

            //GODO TODO Perhaps Make sure to check mimetype, or media type before confirming the download worked
            //GODO TODO got to be something better than this

            guard let fileURL = fileURL,
                let response = response else {
                    ATLog(.error, "No file URL or response from download task: \(self.key)")
                    if let error = error {
                        ATLog(.error, "Specific error reported from download task: \(error.localizedDescription)")
                    }
                    self.delegate?.downloadTaskFailed(self, withError: nil)
                    return
            }

            //GODO TODO audit this if-condition
            let httpResponse = response as? HTTPURLResponse
            if ((error == nil) && (httpResponse?.statusCode == 200)) {

                // GODO TODO only apply mp3 if i know it's an mp3? look at android here
                // GODO TODO especially with the alternates

                let fileManager = FileManager.default
                do {
                    try fileManager.moveItem(at: fileURL, to: toLocalDirectory)
                    ATLog(.debug, "File successfully downloaded and moved to: \(toLocalDirectory)")
                    self.downloadProgress = 1.0
                    self.delegate?.downloadTaskReadyForPlayback(self)
                }
                catch let error as NSError {
                    //GODO TODO flesh out error handling
                    print("File copy to cache directory error: \(error)")
                    self.downloadProgress = 0.0
                    self.delegate?.downloadTaskFailed(self, withError: nil)
                    return
                }
            }
            else {
                //GODO TODO record a non-200 result from the server
                ATLog(.error, "Download Task failed with response: \n\(httpResponse?.description ?? "nil")", error: error)
                self.downloadProgress = 0.0
                self.delegate?.downloadTaskFailed(self, withError: nil)
                return
            }

        }
        task.resume()
    }
    private func hash(_ key: String) -> String? {
        guard let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return nil
        }
        return escapedKey
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
        //GODO TODO
        //Skipped if a completion block is used in download task
        //Potentially not a needed method
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64)
    {
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

