import AVFoundation

class OverdrivePlayer: OpenAccessPlayer {
    override var errorDomain: String {
        return OverdrivePlayerErrorDomain
    }
    
    override var taskCompleteNotification: Notification.Name {
        return OverdriveTaskCompleteNotification
    }
    
    override func assetFileStatus(_ task: DownloadTask) -> AssetResult? {
        guard let task = task as? OverdriveDownloadTask else {
            return nil
        }
        return task.assetFileStatus()
    }
}
