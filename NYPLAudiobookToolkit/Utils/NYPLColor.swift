//
//  NYPLColor.swift
//  NYPLAudiobookToolkit
//
//  Created by Ernest Fan on 2021-10-04.
//  Copyright © 2021 Dean Silfen. All rights reserved.
//

import UIKit

private enum ColorAsset: String {
    case primaryBackground
    case primaryText
    case secondaryBackground
    case action
    case disabledFieldText
    case progressBarBackground
}

class NYPLColor {
    static var primaryBackgroundColor: UIColor {
        if #available(iOS 13.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .light {
            return .systemBackground
        } else if let color = UIColor(named: ColorAsset.primaryBackground.rawValue) {
            return color
        }

        return .white
    }
  
    static var primaryTextColor: UIColor {
        if #available(iOS 13.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .light {
            return .label
        } else if let color = UIColor(named: ColorAsset.primaryText.rawValue) {
            return color
        }

        return .black
    }

    static var secondaryBackgroundColor: UIColor {
        if #available(iOS 13.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .light {
            return .secondarySystemBackground
        } else if let color = UIColor(named: ColorAsset.secondaryBackground.rawValue) {
            return color
        }

        return .lightGray
    }
  
    static var actionColor: UIColor {
        if #available(iOS 13.0, *),
           UIScreen.main.traitCollection.userInterfaceStyle == .light {
            return .link
        } else if let color = UIColor(named: ColorAsset.action.rawValue) {
            return color
        }

        return .systemBlue
    }
  
    static var disabledFieldTextColor: UIColor {
        UIColor(named: ColorAsset.disabledFieldText.rawValue) ?? .lightGray
    }

    static var progressBarBackgroundColor: UIColor {
        UIColor(named: ColorAsset.progressBarBackground.rawValue) ?? .darkGray
    }
}
