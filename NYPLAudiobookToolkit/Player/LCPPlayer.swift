//
//  LCPPlayer.swift
//  NYPLAudiobookToolkit
//
//  Created by Vladimir Fedorov on 19.11.2020.
//  Copyright © 2020 NYPL. All rights reserved.
//

import AVFoundation

class LCPPlayer: OpenAccessPlayer {

    /// DRMDecryptor passed from SimplyE to process encrypted audio files.
    var decryptionDelegate: DRMDecryptor?
    
    /// Task completion notification to notify about the end of decryption process.
    override var taskCompleteNotification: Notification.Name {
        LCPDownloadTaskCompleteNotification
    }
    
    /// Audio file status. LCP audiobooks contain all encrypted audio files inside, this method returns status of decrypted versions of these files.
    /// - Parameter task: `LCPDownloadTask` containing internal url (e.g., `media/sound.mp3`) for decryption.
    /// - Returns: Status of the file, .unknown in case of an error, .missing if the file needs decryption, .saved when accessing an already decrypted file.
    override func assetFileStatus(_ task: DownloadTask) -> AssetResult? {
        if let delegate = decryptionDelegate, let task = task as? LCPDownloadTask, let decryptedUrl = task.decryptedUrl {
            // Return file URL if it already decrypted
            if FileManager.default.fileExists(atPath: decryptedUrl.path) {
                return .saved(decryptedUrl)
            }
            // Decrypt, return .missing to wait for decryption
            delegate.decrypt(url: task.url, to: decryptedUrl) { error in
                if let error = error {
                    ATLog(.error, "Error decrypting file", error: error)
                    return
                }
                DispatchQueue.main.async {
                    // taskCompleteNotification notifies the player to call `play` function again.
                    NotificationCenter.default.post(name: self.taskCompleteNotification, object: task)

                }
            }
            return .missing(task.url)
        }
        return .unknown
    }
    
    @available(*, deprecated, message: "Use init(cursor: Cursor<SpineElement>, audiobookID: String, decryptor: DRMDecryptor?) instead")
    required convenience init(cursor: Cursor<SpineElement>, audiobookID: String, drmOk: Bool) {
        self.init(cursor: cursor, audiobookID: audiobookID, decryptor: nil)
    }
    
    /// Audiobook player
    /// - Parameters:
    ///   - cursor: Player cursor for the audiobook spine.
    ///   - audiobookID: Audiobook identifier.
    ///   - decryptor: LCP DRM decryptor.
    init(cursor: Cursor<SpineElement>, audiobookID: String, decryptor: DRMDecryptor?) {
        super.init(cursor: cursor, audiobookID: audiobookID, drmOk: true)
        self.decryptionDelegate = decryptor
    }
}
