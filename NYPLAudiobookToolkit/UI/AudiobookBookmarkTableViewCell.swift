import UIKit
import PureLayout

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
    let durationReadable = HumanReadableTimestamp(timeInterval: bookmark.duration)
    let offsetReadable = HumanReadableTimestamp(timeInterval: bookmark.time)
    timeLabel.text = "\(offsetReadable.timecode) / \(durationReadable.timecode)"
    timeLabel.accessibilityLabel = "\(offsetReadable.accessibleDescription) / \(durationReadable.accessibleDescription)"

    chapterLabel.text = shouldDisplayChapter ? bookmark.title : ""
    backgroundColor = NYPLColor.primaryBackgroundColor
    dateLabel.text = prettyDate(fromDate: bookmark.creationTime)
  }
  
  // MARK: - Helper
  
  private func prettyDate(fromDate date: Date) -> String {
    return AudiobookBookmarkTableViewCell.dateFormatter.string(from: date)
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
