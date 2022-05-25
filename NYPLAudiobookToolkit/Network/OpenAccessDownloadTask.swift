import AVFoundation
import NYPLUtilities

let OpenAccessTaskCompleteNotification = NSNotification.Name(rawValue: "OpenAccessDownloadTaskCompleteNotification")

enum AssetResult {
    /// The file exists at the given URL.
    case saved(URL)
    /// The file is missing at the given URL.
    case missing(URL)
    /// Could not create a valid URL to check.
    case unknown
}

final class OpenAccessDownloadTask: DownloadTask {

    /// The timeout value is now based on user's connectivity, this is more like a fail-safe
    /// if the timeout timer in the AudiobookNetworkService is not working properly
    private static let DownloadTaskTimeoutValue = 660.0
    
    private var urlSession: URLSession?

    weak var delegate: DownloadTaskDelegate?

    /// For monitoring download task with long download time
    private var fetchStartTime: Date?
    private var downloadTimer: NYPLRepeatingTimer?
    private var downloadTimeLimit: Double
    private var serialQueue: DispatchQueue

    /// Progress should be set to 1 if the file already exists.
    var downloadProgress: Float = 0 {
        didSet {
            self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
        }
    }

    let key: String
    let url: URL
    let urlString: String // Retain original URI for DRM purposes
    let urlMediaType: OpenAccessSpineElementMediaType
    let alternateLinks: [(OpenAccessSpineElementMediaType, URL)]?
    let feedbooksProfile: String?

    init(spineElement: OpenAccessSpineElement) {
        self.key = spineElement.key
        self.url = spineElement.url
        self.urlString = spineElement.urlString
        self.urlMediaType = spineElement.mediaType
        self.alternateLinks = spineElement.alternateUrls
        self.feedbooksProfile = spineElement.feedbooksProfile
        self.downloadTimeLimit = 30.0
        self.serialQueue = DispatchQueue(label: "org.nypl.labs.NYPLAudiobookToolkit.OpenAccessDownloadTask")
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
                fallthrough
            case .audioMP4:
                self.downloadAsset(fromRemoteURL: self.url, toLocalDirectory: missingAssetURL)
            }
            startDownloadTimer()
        case .unknown:
            self.delegate?.downloadTaskFailed(self, withError: nil)
        }
    }

    func delete() {
        switch self.assetFileStatus() {
        case .saved(let url):
            do {
                try FileManager.default.removeItem(at: url)
                self.delegate?.downloadTaskDidDeleteAsset(self)
            } catch {
                ATLog(.error, "FileManager removeItem error", error: error)
            }
        case .missing(_):
            ATLog(.debug, "No file located at directory to delete.")
        case .unknown:
            ATLog(.error, "Invalid file directory from command")
        }
    }
  
    func cancel() {
        switch self.assetFileStatus() {
        case .saved(_):
            break
        default:
            self.urlSession?.invalidateAndCancel()
        }
        removeDownloadTimer()
    }

    func assetFileStatus() -> AssetResult {
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

        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in

            guard let data = data,
                let response = response,
                (error == nil) else {
                ATLog(.error, "Network request failed for RBDigital partial file. Error: \(error!.localizedDescription)")
                self?.removeDownloadTimer()
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
                            fallthrough
                        case .audioMP4:
                            self?.downloadAsset(fromRemoteURL: assetUrl, toLocalDirectory: localURL)
                        case .rbDigital:
                            ATLog(.error, "Wrong media type for download task.")
                            self?.removeDownloadTimer()
                        }
                    } else {
                        ATLog(.error, "Invalid or missing property in JSON response to download task.")
                    }
                } catch {
                    ATLog(.error, "Error deserializing JSON in download task.", error: error)
                }
            } else {
                ATLog(.error, "Failed with server response: \n\(response.description)")
            }
        }
        task.resume()
    }

    private func downloadAsset(fromRemoteURL remoteURL: URL, toLocalDirectory finalURL: URL)
    {
        let config = URLSessionConfiguration.ephemeral
        let delegate = OpenAccessDownloadTaskURLSessionDelegate(downloadTask: self,
                                                                delegate: self.delegate,
                                                                finalDirectory: finalURL)
        urlSession = URLSession(configuration: config,
                                delegate: delegate,
                                delegateQueue: nil)
        var request = URLRequest(url: remoteURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: OpenAccessDownloadTask.DownloadTaskTimeoutValue)
        
        // Feedbooks DRM
        if let profile = self.feedbooksProfile {
            request.setValue("Bearer \(FeedbookDRMProcessor.getJWTToken(profile: profile, resourceUri: urlString) ?? "")", forHTTPHeaderField: "Authorization")
        }
        
        guard let urlSession = urlSession else {
            return
        }
        
        let task = urlSession.downloadTask(with: request)
        task.resume()
    }

    private func hash(_ key: String) -> String? {
        guard let hash = key.sha256 else {
            return nil
        }
        return hash
    }
  
    // MARK: - Download Timer
  
    private func startDownloadTimer() {
        serialQueue.async {
            /// These value should be reset every time we start fetching,
            /// so that we have the right time in case of retrying download
            self.fetchStartTime = Date()
            self.downloadTimeLimit = 30.0
            
            self.downloadTimer = NYPLRepeatingTimer(interval: .seconds(30),
                                                    queue: self.serialQueue,
                                                    handler: { [weak self] in
                guard let self = self,
                      let startTime = self.fetchStartTime else {
                    return
                }
              
                let elapsedTime = Date().timeIntervalSince(startTime)
                if elapsedTime >= self.downloadTimeLimit {
                    self.delegate?.downloadTaskExceededTimeLimit(self,
                                                                 elapsedTime: elapsedTime)
                    self.updateDownloadTimeLimit()
                }
            })
        }
    }
  
    fileprivate func removeDownloadTimer() {
        serialQueue.async {
            self.downloadTimer = nil
        }
    }
  
    /// We call the delegate when the download task has not completed
    /// at the 30 seconds mark and 3 minutes (180 seconds) mark.
    /// Therefore, we update the time limit every time the delegate is called and
    /// remove the timer when we are done with it.
    private func updateDownloadTimeLimit() {
        serialQueue.async {
            if self.downloadTimeLimit == 30.0 {
                self.downloadTimeLimit = 180.0
            } else if self.downloadTimeLimit == 180.0 {
                self.removeDownloadTimer()
            }
        }
    }
}

final class OpenAccessDownloadTaskURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {

    private let downloadTask: OpenAccessDownloadTask
    private let delegate: DownloadTaskDelegate?
    private let finalURL: URL

    /// Each Spine Element's Download Task has a URLSession delegate.
    /// If the player ever evolves to support concurrent requests, there
    /// should just be one delegate objects that keeps track of them all.
    /// This is only for the actual audio file download.
    ///
    /// - Parameters:
    ///   - downloadTask: The corresponding download task for the URLSession.
    ///   - delegate: The DownloadTaskDelegate, to forward download progress
    ///   - finalDirectory: Final directory to move the asset to
    required init(downloadTask: OpenAccessDownloadTask,
                  delegate: DownloadTaskDelegate?,
                  finalDirectory: URL) {
        self.downloadTask = downloadTask
        self.delegate = delegate
        self.finalURL = finalDirectory
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        self.downloadTask.removeDownloadTimer()
        guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
            ATLog(.error, "Response could not be cast to HTTPURLResponse: \(self.downloadTask.key)")
            self.delegate?.downloadTaskFailed(self.downloadTask, withError: nil)
            return
        }

        if (httpResponse.statusCode == 200) {
            verifyDownloadAndMove(from: location, to: self.finalURL) { (success) in
                if success {
                    ATLog(.debug, "File successfully downloaded and moved to: \(self.finalURL)")
                    if FileManager.default.fileExists(atPath: location.path) {
                        do {
                            try FileManager.default.removeItem(at: location)
                        } catch {
                            ATLog(.error, "Could not remove original downloaded file at \(location.absoluteString)",
                                  error: error)
                        }
                    }
                    self.downloadTask.downloadProgress = 1.0
                    self.delegate?.downloadTaskReadyForPlayback(self.downloadTask)
                    NotificationCenter.default.post(name: OpenAccessTaskCompleteNotification, object: self.downloadTask)
                } else {
                    self.downloadTask.downloadProgress = 0.0
                    self.delegate?.downloadTaskFailed(self.downloadTask, withError: nil)
                }
            }
        } else {
            ATLog(.error, "Download Task failed with server response: \n\(httpResponse.description)")
            self.downloadTask.downloadProgress = 0.0
            self.delegate?.downloadTaskFailed(self.downloadTask, withError: nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        self.downloadTask.removeDownloadTimer()
        ATLog(.debug, "urlSession:task:didCompleteWithError: curl representation \(task.originalRequest?.curlString ?? "")")
        guard let error = error else {
            ATLog(.debug, "urlSession:task:didCompleteWithError: no error.")
            return
        }

        ATLog(.error, "No file URL or response from download task: \(self.downloadTask.key).", error: error)

        if let code = (error as NSError?)?.code {
            switch code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost:
                let networkLossError = NSError(domain: OpenAccessPlayerErrorDomain, code: OpenAccessPlayerError.connectionLost.rawValue, userInfo: nil)
                self.delegate?.downloadTaskFailed(self.downloadTask, withError: networkLossError)
                return
            default:
                break
            }
        }

        self.delegate?.downloadTaskFailed(self.downloadTask, withError: error as NSError?)
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
            self.downloadTask.downloadProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        }
    }
    
    func verifyDownloadAndMove(from: URL, to: URL, completionHandler: @escaping (Bool) -> Void) {
        if MediaProcessor.fileNeedsOptimization(url: from) {
            ATLog(.debug, "Media file needs optimization: \(from.absoluteString)")
            MediaProcessor.optimizeQTFile(input: from, output: to, completionHandler: completionHandler)
        } else {
            do {
                try FileManager.default.moveItem(at: from, to: to)
                completionHandler(true)
            } catch {
                ATLog(.error, "FileManager removeItem error", error: error)
                completionHandler(false)
            }
        }
    }
}
