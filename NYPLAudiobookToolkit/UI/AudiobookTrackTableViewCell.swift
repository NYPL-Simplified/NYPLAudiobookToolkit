import UIKit

class AudiobookTrackTableViewCell: UITableViewCell {
  
  static let cellIdentifier = "AudiobookTrackTableViewCell"

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    // Use `.value1` to display label on the right side of the cell
    super.init(style: .value1, reuseIdentifier: reuseIdentifier)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    let view = UIView()
    view.backgroundColor = NYPLColor.primaryBackgroundColor.withAlphaComponent(0.1)
    self.selectedBackgroundView = view
  }

  func configureFor(_ spineElement: SpineElement) {
    let progress = spineElement.downloadTask.downloadProgress
    let spineDuration = spineElement.chapter.duration
    let title = spineElement.chapter.title
    let detailLabel: String
    let labelAlpha: CGFloat
    if progress > 0 && progress < 1  {
      // Spine element downloading in progress
      let percentage = HumanReadablePercentage(percentage: progress).value
      let labelFormat = NSLocalizedString("Downloading: %@%%", bundle: Bundle.audiobookToolkit()!, value: "Downloading: %@%%", comment: "The percentage of the chapter that has been downloaded, formatting for string should be localized at this point.")
      detailLabel = String(format: labelFormat, percentage)
      labelAlpha = 0.4
    } else if (progress == 1 || spineElement.downloadTask.downloadCompleted) {
      // Spine element download completed
      detailLabel = customFormatString(for: spineDuration)
      labelAlpha = 1.0
    } else {
      // Spine element download not started
      detailLabel = customFormatString(for: spineDuration)
      labelAlpha = 0.4
    }

    self.textLabel?.text = title
    self.textLabel?.alpha = labelAlpha
    self.detailTextLabel?.text = detailLabel
    self.backgroundColor = NYPLColor.primaryBackgroundColor
  }
  
  func customFormatString(for spineDuration: TimeInterval) -> String {
    let duration = HumanReadableTimestamp(timeInterval: spineDuration).timecode
    self.detailTextLabel?.accessibilityLabel = HumanReadableTimestamp(timeInterval: spineDuration).accessibleDescription
    let labelFormat = NSLocalizedString("%@", bundle: Bundle.audiobookToolkit()!, value: "%@", comment: "Timecode that means the length of the track")
    return String(format: labelFormat, duration)
  }
}
