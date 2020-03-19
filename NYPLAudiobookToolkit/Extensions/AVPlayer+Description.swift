import AVFoundation

extension AVPlayer.Status {
  var description: String {
    var s = ""
    switch self {
    case .failed:
      s = "failed"
    case .readyToPlay:
      s = "readyToPlay"
    case .unknown:
      s = "unknown"
    }
    return s
  }
}

extension AVPlayerItem.Status {
  var description: String {
    var s = ""
    switch self {
    case .failed:
      s = "failed"
    case .readyToPlay:
      s = "readyToPlay"
    case .unknown:
      s = "unknown"
    }
    return s
  }
}
