//
//  LCPDownloadTask.swift
//  NYPLAudiobookToolkit
//
//  Created by Vladimir Fedorov on 19.11.2020.
//  Copyright © 2020 Dean Silfen. All rights reserved.
//

import Foundation

let LCPDownloadTaskCompleteNotification = NSNotification.Name(rawValue: "LCPDownloadTaskCompleteNotification")
/**
 This file is created for protocol conformance.
 All audio files are embedded into LCP-protected audiobook file.
 */
final class LCPDownloadTask: DownloadTask {
    
    func fetch() {
        // No need to download files.
    }
    
    /// Delete decrypted file
    func delete() {
        let fileManager = FileManager.default
        guard let url = decryptedUrl, fileManager.fileExists(atPath: url.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            ATLog(.warn, "Could not delete decrypted file.", error: error)
        }
    }
    
    /// All encrypted files are included in the audiobook, download progress is 1.0
    let downloadProgress: Float = 1.0
    
    /// Spine element key
    let key: String
    
    /// URL of a file inside the audiobook archive (e.g., `media/sound.mp3`)
    let url: URL
    
    /// URL for decrypted audio file
    var decryptedUrl: URL?
    
    let urlMediaType: LCPSpineElementMediaType
    
    weak var delegate: DownloadTaskDelegate?
    
    init(spineElement: LCPSpineElement) {
        self.key = spineElement.key
        self.url = spineElement.url
        self.urlMediaType = spineElement.mediaType
        self.decryptedUrl = decryptedFileURL(for: self.url)
    }

    /// URL for decryption delegate to store decrypted file.
    /// - Parameter url: Internal file URL (e.g., `media/sound.mp3`).
    /// - Returns: `URL` to store decrypted file.
    private func decryptedFileURL(for url: URL) -> URL? {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            ATLog(.error, "Could not find caches directory.")
            return nil
        }
        guard let hashedUrl = NYPLStringAdditions.sha256forString(url.path) else {
            ATLog(.error, "Could not create a valid hash from download task ID.")
            return nil
        }
        return cacheDirectory.appendingPathComponent(hashedUrl).appendingPathExtension(url.pathExtension)
    }
}
