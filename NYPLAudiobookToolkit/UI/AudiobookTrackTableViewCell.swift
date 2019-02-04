import UIKit

class AudiobookTrackTableViewCell: UITableViewCell {

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let view = UIView()
        view.backgroundColor = view.tintColor.withAlphaComponent(0.1)
        self.selectedBackgroundView = view
    }

    func configureFor(_ spineElement: SpineElement) {
        let progress = spineElement.downloadTask.downloadProgress
        let spineDuration = spineElement.chapter.duration
        let title = spineElement.chapter.title
        let detailLabel: String
        let labelAlpha: CGFloat
        if progress == 0 {
            let duration = HumanReadableTimestamp(timeInterval: spineDuration).timecode
            self.detailTextLabel?.accessibilityLabel = HumanReadableTimestamp(timeInterval: spineDuration).accessibleDescription
            let labelFormat = NSLocalizedString("%@", bundle: Bundle.audiobookToolkit()!, value: "%@", comment: "Timecode that means the length of the track")
            detailLabel = String(format: labelFormat, duration)
            labelAlpha = 0.4
        } else if progress > 0 && progress < 1  {
            let percentage = HumanReadablePercentage(percentage: progress).value
            let labelFormat = NSLocalizedString("Downloading: %@%%", bundle: Bundle.audiobookToolkit()!, value: "Downloading: %@%%", comment: "The percentage of the chapter that has been downloaded, formatting for string should be localized at this point.")
            detailLabel = String(format: labelFormat, percentage)
            labelAlpha = 0.4
        } else {
            let duration = HumanReadableTimestamp(timeInterval: spineDuration).timecode
            self.detailTextLabel?.accessibilityLabel = HumanReadableTimestamp(timeInterval: spineDuration).accessibleDescription
            let labelFormat = NSLocalizedString("%@", bundle: Bundle.audiobookToolkit()!, value: "%@", comment: "Timecode that means the length of the track")
            detailLabel = String(format: labelFormat, duration)
            labelAlpha = 1.0
        }

        self.textLabel?.text = title
        self.textLabel?.alpha = labelAlpha
        self.detailTextLabel?.text = detailLabel
        self.backgroundColor = .white
    }
}
