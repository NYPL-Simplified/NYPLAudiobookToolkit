import UIKit

final class DownloadProgressView: UIView {

    private let ViewHeight: CGFloat = 30.0
    private let SubviewPadding: CGFloat = 8.0

    private let progressView = UIProgressView()
    private let downloadLabel = UILabel()
    private let percentageLabel = UILabel()
    private var heightConstraint: NSLayoutConstraint?

    required init() {
        super.init(frame: .zero)
        setupView()
        updateColors()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 12.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            updateColors()
        }
    }

    private func setupView() {
        isHidden = true
        heightConstraint = autoSetDimension(.height, toSize: 0.0)

        downloadLabel.clipsToBounds = true
        downloadLabel.text = NSLocalizedString("Downloading", comment: "")
        downloadLabel.textColor = .white
        downloadLabel.font = UIFont.systemFont(ofSize: 12.0)

        percentageLabel.clipsToBounds = true
        percentageLabel.text = NSLocalizedString("--", comment: "")
        percentageLabel.textColor = .white
        percentageLabel.font = UIFont.systemFont(ofSize: 12.0)

        progressView.clipsToBounds = true

        addSubview(downloadLabel)
        addSubview(progressView)
        addSubview(percentageLabel)
        downloadLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        downloadLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: SubviewPadding)
        downloadLabel.autoPinEdge(.trailing, to: .leading, of: progressView, withOffset: -SubviewPadding)
        percentageLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        percentageLabel.autoPinEdge(.leading, to: .trailing, of: progressView, withOffset: SubviewPadding)
        percentageLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: SubviewPadding)
        progressView.autoAlignAxis(toSuperviewAxis: .horizontal)
        progressView.autoSetDimension(.height, toSize: 5.0)
    }

    func beginShowingProgress() {
        isHidden = false
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.heightConstraint?.constant = self.ViewHeight
            self.superview?.layoutIfNeeded()
        })
    }

    func stopShowingProgress() {
        isHidden = true
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.heightConstraint?.constant = 0.0
            self.superview?.layoutIfNeeded()
        })
    }

    func updateProgress(_ progress: Float) {
        progressView.progress = progress
        let percent = Int(progress * 100)
        percentageLabel.text = "\(percent)%"
    }
    
    private func updateColors() {
        if #available(iOS 12.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            progressView.progressTintColor = NYPLColor.actionColor
            progressView.trackTintColor = NYPLColor.progressBarBackgroundColor
        } else {
            progressView.progressTintColor = .white
            progressView.trackTintColor = .darkGray
        }
    }
}
