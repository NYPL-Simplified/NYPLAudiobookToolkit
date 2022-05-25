import AVFoundation
import NYPLUtilities

let OverdriveTaskCompleteNotification = NSNotification.Name(rawValue: "OverdriveDownloadTaskCompleteNotification")

final class OverdriveDownloadTask: DownloadTask {

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
    let urlMediaType: OverdriveSpineElementMediaType

    init(spineElement: OverdriveSpineElement) {
        self.key = spineElement.key
        self.url = spineElement.url
        self.urlMediaType = spineElement.mediaType
        self.downloadTimeLimit = 30.0
        self.serialQueue = DispatchQueue(label: "org.nypl.labs.NYPLAudiobookToolkit.OverdriveDownloadTask")
    }
    
    func fetch() {
        switch self.assetFileStatus() {
        case .saved(_):
            downloadProgress = 1.0
            self.delegate?.downloadTaskReadyForPlayback(self)
        case .missing(let missingAssetURL):
            switch urlMediaType {
            case .audioMP3:
                self.downloadAsset(fromRemoteURL: self.url, toLocalDirectory: missingAssetURL)
                startDownloadTimer()
            }
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
    
    private func downloadAsset(fromRemoteURL remoteURL: URL, toLocalDirectory finalURL: URL)
    {
        let config = URLSessionConfiguration.ephemeral
        let delegate = OverdriveDownloadTaskURLSessionDelegate(downloadTask: self,
                                                               delegate: self.delegate,
                                                               finalDirectory: finalURL)
        urlSession = URLSession(configuration: config,
                                delegate: delegate,
                                delegateQueue: nil)
        
        let request = URLRequest(url: remoteURL,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: OverdriveDownloadTask.DownloadTaskTimeoutValue)
        
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

final class OverdriveDownloadTaskURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {

    private let downloadTask: OverdriveDownloadTask
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
    required init(downloadTask: OverdriveDownloadTask,
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
                    NotificationCenter.default.post(name: OverdriveTaskCompleteNotification, object: self.downloadTask)
                } else {
                    self.downloadTask.downloadProgress = 0.0
                    self.delegate?.downloadTaskFailed(self.downloadTask, withError: nil)
                }
            }
        } else {
            ATLog(.error, "Download Task failed with server response: \n\(httpResponse.description)")
            self.downloadTask.downloadProgress = 0.0
            var error:NSError? = nil
            if (httpResponse.statusCode == 410) {
                error = NSError(domain: OverdrivePlayerErrorDomain,
                                code: OverdrivePlayerError.downloadExpired.rawValue,
                                userInfo: ["error cause": "download task failed",
                                           "request": downloadTask.originalRequest ?? "",
                                           "response": httpResponse])
            }
            self.delegate?.downloadTaskFailed(self.downloadTask, withError: error)
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
                let networkLossError = NSError(domain: OverdrivePlayerErrorDomain,
                                               code: OverdrivePlayerError.connectionLost.rawValue,
                                               userInfo: ["error cause": "connection loss",
                                                          "request": task.originalRequest ?? "",
                                                          "error": error])
                self.delegate?.downloadTaskFailed(self.downloadTask,
                                                  withError: networkLossError)
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
