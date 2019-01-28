final class OpenAccessDownloadTask: DownloadTask {

    private let DownloadTaskTimeoutValue = 60.0

    weak var delegate: DownloadTaskDelegate?

    var downloadProgress: Float = 0 {
        didSet {
            self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
        }
    }

    let key: String
    let url: URL
    let urlMediaType: OpenAccessSpineElementMediaType
    let alternateLinks: [(OpenAccessSpineElementMediaType, URL)]?

    //GODO TODO shouldn't delegate be in the init here?
    public init(spineElement: OpenAccessSpineElement) {
        self.key = spineElement.key
        self.url = spineElement.url
        self.urlMediaType = spineElement.mediaType
        self.alternateLinks = spineElement.alternateUrls
    }

    /// If the asset is already downloaded, return immediately and update state.
    /// If not, attempt to download the file and move it into position.
    func fetch() {

        let fileManager = FileManager.default
        let cacheDirectories = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDirectory = cacheDirectories.first else {
            ATLog(.error, "Could not find caches directory.")
            self.delegate?.downloadTask(self, didReceive: nil)
            return
        }
        guard let escapedKey = self.key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            ATLog(.error, "Could not create a valid escaped unique ID for download task.")
            self.delegate?.downloadTask(self, didReceive: nil)
            return
        }

        let assetURL = cacheDirectory.appendingPathComponent("\(escapedKey)", isDirectory: false).appendingPathExtension("mp3")

        if fileManager.fileExists(atPath: assetURL.path) {
            downloadProgress = 1.0
            self.delegate?.downloadTaskReadyForPlayback(self)
            return
        }

        switch urlMediaType {
        case .rbDigital:
            downloadRBDigitalPartial(toLocalDirectory: assetURL)
        case .audioMPEG:
            downloadAsset(fromRemoteURL: self.url, toLocalDirectory: assetURL)
        }
    }

    func delete() {

        //GODO TODO
      
    }

    //GODO TODO remember to add a method to delete all cached content, which could be called by a host when a user is signing out

    /// RBDigital media types first download an intermediate document, which points
    /// to the url of the actual asset to download.
    private func downloadRBDigitalPartial(toLocalDirectory localURL: URL) {

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
                                 delegate: OpenAccessDownloadTaskURLSessionDelegate(),
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
}

final class OpenAccessDownloadTaskURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        //GODO TODO
        //Skipped if a completion block is used in download task
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        //GODO TODO
        //For download progress
    }
}

