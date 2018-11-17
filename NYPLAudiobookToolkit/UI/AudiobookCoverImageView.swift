import UIKit
import MediaPlayer

public class AudiobookCoverImageView: UIImageView {

    override init(image: UIImage?) {
        super.init(image: image)

        isUserInteractionEnabled = true
        accessibilityIdentifier = "cover_art"
        layer.cornerRadius = 10
        layer.masksToBounds = true
        contentMode = .scaleAspectFill
        isAccessibilityElement = true
        accessibilityLabel = NSLocalizedString("Cover", bundle: Bundle.audiobookToolkit()!, value: "Cover", comment:"The art on an album cover.")
        if #available(iOS 11.0, *) {
            accessibilityIgnoresInvertColors = true
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var image: UIImage? {
        didSet {
            super.image = image
            updateLockScreenCoverArtwork(image: image)
        }
    }

    private func updateLockScreenCoverArtwork(image: UIImage?) {
        if let image = image {
            var itemArtwork: MPMediaItemArtwork
            if #available(iOS 10.0, *) {
                itemArtwork = MPMediaItemArtwork.init(boundsSize: image.size) { requestedSize -> UIImage in
                    let rect = CGRect(origin: .zero, size: requestedSize)
                    let imageRef = image.cgImage!.cropping(to: rect)!
                    return UIImage(cgImage:imageRef)
                } 
            } else {
                itemArtwork = MPMediaItemArtwork(image: image)
            }

            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
            info[MPMediaItemPropertyArtwork] = itemArtwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}
