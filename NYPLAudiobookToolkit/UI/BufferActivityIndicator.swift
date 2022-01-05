import UIKit

class BufferActivityIndicatorView: UIActivityIndicatorView {

    var debounceTimer: Timer? = nil {
        willSet {
            debounceTimer?.invalidate()
        }
    }

    private let debounceTimeInterval = 1.0

    override func startAnimating() {
        super.startAnimating()

        // Announce a "buffer" to VoiceOver with sufficient debounce...
        if debounceTimer == nil {
            debounceTimer = Timer.scheduledTimer(timeInterval: debounceTimeInterval,
                                                 target: self,
                                                 selector: #selector(debounceFunction),
                                                 userInfo: nil,
                                                 repeats: false)
        }
    }

    override func stopAnimating() {
        super.stopAnimating()

        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    @objc func debounceFunction() {
        let announcementString = NSLocalizedString("Loading",
                                                   bundle: Bundle.audiobookToolkit()!,
                                                   value: "Loading",
                                                   comment: "Quickly announce to VoiceOver that some data is loading and there may be a wait.")
        UIAccessibility.post(notification: .announcement, argument: announcementString)
    }
}
