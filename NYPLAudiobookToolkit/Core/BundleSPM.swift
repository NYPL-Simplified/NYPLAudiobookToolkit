//
//  BundleSPM.swift
//  NYPLAudiobookToolkit
//
//  Created by Ettore Pasquini on 1/5/22.
//  Copyright © 2022 NYPL. All rights reserved.
//

import UIKit

// Use this only when building via SPM.
extension Bundle {
    static func audiobookToolkit() -> Bundle? {
      return Bundle.module
    }
}
