import UIKit

class AudiobookBookmarkTableViewCell: UITableViewCell {
  
  static let cellIdentifier = "AudiobookBookmarkTableViewCell"
  
  private static var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .short
    return formatter
  }()
  
  private let defaultVerticalPadding: CGFloat = 10.0
  private let defaultHorizontalPadding: CGFloat = 16.0

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    setupUI()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setupUI() {
    addSubview(chapterLabel)
    chapterLabel.autoPinEdgesToSuperviewSafeArea(with: .init(top: defaultVerticalPadding, left: defaultHorizontalPadding, bottom: 0, right: defaultHorizontalPadding), excludingEdge: .bottom)
    
    let stackView = UIStackView(arrangedSubviews: [dateLabel, timeLabel])
    stackView.distribution = .fillProportionally
    stackView.spacing = defaultHorizontalPadding
    stackView.axis = .horizontal
    addSubview(stackView)
    
    stackView.autoPinEdge(.top, to: .bottom, of: chapterLabel, withOffset: defaultVerticalPadding)
    stackView.autoPinEdgesToSuperviewSafeArea(with: .init(top: 0, left: defaultHorizontalPadding * 2, bottom: defaultVerticalPadding, right: defaultHorizontalPadding), excludingEdge: .top)
  }
  
  func configure(for bookmark: NYPLAudiobookBookmark, shouldDisplayChapter: Bool) {
    let durationString = customFormatString(for: bookmark.duration)
    let offsetString = customFormatString(for: bookmark.time)
    
    let detailLabelString = "\(offsetString) / \(durationString)"

    chapterLabel.text = shouldDisplayChapter ? bookmark.title : ""
    timeLabel.text = detailLabelString
    backgroundColor = NYPLColor.primaryBackgroundColor
    dateLabel.text = prettyDate(fromDate: bookmark.creationTime)
  }
  
  // MARK: - Helper
  
  private func prettyDate(fromDate date: Date) -> String {
    return AudiobookBookmarkTableViewCell.dateFormatter.string(from: date)
  }
  
  private func customFormatString(for spineDuration: TimeInterval) -> String {
    let duration = HumanReadableTimestamp(timeInterval: spineDuration).timecode
    self.detailTextLabel?.accessibilityLabel = HumanReadableTimestamp(timeInterval: spineDuration).accessibleDescription
    let labelFormat = NSLocalizedString("%@", bundle: Bundle.audiobookToolkit()!, value: "%@", comment: "Timecode that means the length of the track")
    return String(format: labelFormat, duration)
  }
  
  // MARK: - UI Properties
  
  lazy var chapterLabel: UILabel = {
    let label = UILabel()
    label.textColor = NYPLColor.primaryTextColor
    label.textAlignment = .left
    label.backgroundColor = .clear
    return label
  }()
  
  lazy var dateLabel: UILabel = {
    let label = UILabel()
    label.textColor = NYPLColor.primaryTextColor
    label.textAlignment = .left
    label.backgroundColor = .clear
    return label
  }()
  
  lazy var timeLabel: UILabel = {
    let label = UILabel()
    label.textColor = NYPLColor.primaryTextColor
    label.textAlignment = .right
    label.backgroundColor = .clear
    return label
  }()
}
