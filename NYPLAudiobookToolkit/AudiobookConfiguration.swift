//
//  AudiobookConfiguration.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/12/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

public class AudiobookConfiguration: NSObject {
    
    let restrictDownloadsToWiFi: Bool
    
    public static var defaultConfiguration : AudiobookConfiguration {
        return AudiobookConfiguration(
            restrictDownloadsToWiFi: true
        )
    }

    public init(restrictDownloadsToWiFi: Bool) {
        self.restrictDownloadsToWiFi = restrictDownloadsToWiFi
    }
}
