import UIKit

final class DownloadProgressView: UIView {

    private let ViewHeight: CGFloat = 30.0
    private let SubviewPadding: CGFloat = 8.0

    let progressView = UIProgressView()
    private let label = UILabel()
    private var heightConstraint: NSLayoutConstraint?

    required init() {
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .white
        isHidden = true
        heightConstraint = autoSetDimension(.height, toSize: 0.0)

        label.clipsToBounds = true
        label.text = NSLocalizedString("Downloading", comment: "")
        label.font = UIFont.systemFont(ofSize: 12.0)

        progressView.clipsToBounds = true
        progressView.tintColor = tintColor

        addSubview(label)
        addSubview(progressView)
        label.autoAlignAxis(toSuperviewAxis: .horizontal)
        label.autoPinEdge(toSuperviewEdge: .leading, withInset: SubviewPadding)
        label.autoPinEdge(.trailing, to: .leading, of: progressView, withOffset: -SubviewPadding)
        progressView.autoAlignAxis(toSuperviewAxis: .horizontal)
        progressView.autoPinEdge(toSuperviewEdge: .trailing, withInset: SubviewPadding)
        progressView.autoSetDimension(.height, toSize: 6.0)
    }

    func beginShowingProgress() {
        isHidden = false
        self.heightConstraint?.constant = self.ViewHeight
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            self.superview?.layoutIfNeeded()
        })
    }

    func stopShowingProgress() {
        isHidden = true
        self.heightConstraint?.constant = 0.0
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            self.superview?.layoutIfNeeded()
        })
    }
}
