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

/// To improve the user experience, we need the information of download task
/// that takes a longer than usual time to complete.
/// We implement a timer to log warning statements through delegate method
/// when the download task reaches 30 seconds and 180 seconds marks.
/// The timer is removed when a download task completes, fails or is being cancelled.
final class OpenAccessDownloadTask: DownloadTask {
    
    private var urlSession: URLSession?

    weak var delegate: DownloadTaskDelegate?

    /// For monitoring download task with long download time.
    private var fetchStartTime: Date?
    /// Timer for monitoring the duration of the download task takes to complete.
    /// We log a warning statement by calling the delegates
    /// when the download task reaches 30s and 180s marks.
    private var monitoringTimer: NYPLRepeatingTimer?
    private var downloadTimeLimit: TimeInterval
    private var serialQueue: DispatchQueue

    /// Progress should be set to 1 if the file already exists.
    var downloadProgress: Float = 0 {
        didSet {
            self.delegate?.downloadTaskDidUpdateDownloadPercentage(self)
        }
    }
  
    /// Since download progress would be 0 if the download has not begun,
    /// we use this computed property to check if the file has been downloaded or not.
    var downloadCompleted: Bool {
        switch assetFileStatus() {
        case .saved(_):
            return true
        default:
            return false
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
        self.downloadTimeLimit = OpenAccessDownloadTask.firstDownloadTimeLimit
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
                self?.notifyDelegateOfDownloadTaskFailed(error: nil)
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
                            self?.notifyDelegateOfDownloadTaskFailed(error: nil)
                        }
                    } else {
                        ATLog(.error, "Invalid or missing property in JSON response to download task.")
                        self?.notifyDelegateOfDownloadTaskFailed(error: nil)
                    }
                } catch {
                    ATLog(.error, "Error deserializing JSON in download task.", error: error)
                    self?.notifyDelegateOfDownloadTaskFailed(error: error as NSError)
                }
            } else {
                ATLog(.error, "Failed with server response: \n\(response.description)")
                self?.notifyDelegateOfDownloadTaskFailed(error: nil)
            }
        }
        task.resume()
    }

    private func downloadAsset(fromRemoteURL remoteURL: URL, toLocalDirectory finalURL: URL)
    {
        let config = URLSessionConfiguration.ephemeral
        let delegate = OpenAccessDownloadTaskURLSessionDelegate(downloadTask: self,
                                                                finalDirectory: finalURL)
        urlSession = URLSession(configuration: config,
                                delegate: delegate,
                                delegateQueue: nil)
        var request = URLRequest(url: remoteURL,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: OpenAccessDownloadTask.timeoutValue)
        
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
        serialQueue.async { [weak self] in
            guard let self = self else {
                return
            }
          
            /// These value should be reset every time we start fetching,
            /// so that we have the right time in case of retrying download
            self.fetchStartTime = Date()
            self.downloadTimeLimit = OpenAccessDownloadTask.firstDownloadTimeLimit
            
            self.monitoringTimer = NYPLRepeatingTimer(interval: OpenAccessDownloadTask.monitoringTimerInterval,
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
        serialQueue.async { [weak self] in
            self?.monitoringTimer = nil
        }
    }
  
    /// We call the delegate to log a warning statement when the download task
    /// has not completed at the 30 seconds mark and 3 minutes (180 seconds) mark.
    /// Therefore, we update the time limit every time the delegate is called and
    /// remove the timer when we are done with it.
    private func updateDownloadTimeLimit() {
        serialQueue.async { [weak self] in
            if self?.downloadTimeLimit == OpenAccessDownloadTask.firstDownloadTimeLimit {
                self?.downloadTimeLimit = OpenAccessDownloadTask.secondDownloadTimeLimit
            } else {
                self?.removeDownloadTimer()
            }
        }
    }
    
    // MARK: - Notify delegate
    
    fileprivate func notifyDelegateOfDownloadTaskReadyForPlayback() {
        self.removeDownloadTimer()
        self.delegate?.downloadTaskReadyForPlayback(self)
    }
  
    fileprivate func notifyDelegateOfDownloadTaskFailed(error: NSError?) {
        self.removeDownloadTimer()
        self.delegate?.downloadTaskFailed(self, withError: error)
    }
}

final class OpenAccessDownloadTaskURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {

    private let downloadTask: OpenAccessDownloadTask
    private let finalURL: URL

    /// Each Spine Element's Download Task has a URLSession delegate.
    /// If the player ever evolves to support concurrent requests, there
    /// should just be one delegate objects that keeps track of them all.
    /// This is only for the actual audio file download.
    ///
    /// - Parameters:
    ///   - downloadTask: The corresponding download task for the URLSession.
    ///   - finalDirectory: Final directory to move the asset to
    required init(downloadTask: OpenAccessDownloadTask,
                  finalDirectory: URL) {
        self.downloadTask = downloadTask
        self.finalURL = finalDirectory
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
            ATLog(.error, "Response could not be cast to HTTPURLResponse: \(self.downloadTask.key)")
            self.downloadTask.notifyDelegateOfDownloadTaskFailed(error: nil)
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
                    self.downloadTask.notifyDelegateOfDownloadTaskReadyForPlayback()
                    NotificationCenter.default.post(name: OpenAccessTaskCompleteNotification, object: self.downloadTask)
                } else {
                    self.downloadTask.downloadProgress = 0.0
                    self.downloadTask.notifyDelegateOfDownloadTaskFailed(error: nil)
                }
            }
        } else {
            ATLog(.error, "Download Task failed with server response: \n\(httpResponse.description)")
            self.downloadTask.downloadProgress = 0.0
            self.downloadTask.notifyDelegateOfDownloadTaskFailed(error: nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
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
                self.downloadTask.notifyDelegateOfDownloadTaskFailed(error: networkLossError)
                return
            default:
                break
            }
        }

        self.downloadTask.notifyDelegateOfDownloadTaskFailed(error: error as NSError?)
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
