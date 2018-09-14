import UIKit

class AudiobookTrackTableViewCell: UITableViewCell {

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let view = UIView()
        view.backgroundColor = .red
        self.selectedBackgroundView = view
    }

    func configureFor(_ spineElement: SpineElement) {
        let progress = spineElement.downloadTask.downloadProgress
        let title = spineElement.chapter.title
        let detailLabel: String
        let backgroundColor: UIColor
        if progress == 0 {
            detailLabel = NSLocalizedString("Not Downloaded", bundle: Bundle.audiobookToolkit()!, value: "Not Downloaded", comment: "Track has not been  downloaded to the user's phone")
            backgroundColor = .white
        } else if progress > 0 && progress < 1  {
            let percentage = HumanReadablePercentage(percentage: progress).value
            let labelFormat = NSLocalizedString("Downloading %@", bundle: Bundle.audiobookToolkit()!, value: "Downloading %@", comment: "The percentage of the chapter that has been downloaded, formatting for string should be localized at this point.")
            detailLabel = String(format: labelFormat, percentage)
            backgroundColor = .white
        } else {
            let duration = HumanReadableTimestamp(timeInterval: spineElement.chapter.duration).value
            let labelFormat = NSLocalizedString("Duration %@", bundle: Bundle.audiobookToolkit()!, value: "Duration %@", comment: "Duration of the track, with formatting for a previously localized string to be inserted.")
            detailLabel = String(format: labelFormat, duration)
            backgroundColor = .white
        }

        self.textLabel?.text = title
        self.detailTextLabel?.text = detailLabel
        self.backgroundColor = backgroundColor
    }
}
