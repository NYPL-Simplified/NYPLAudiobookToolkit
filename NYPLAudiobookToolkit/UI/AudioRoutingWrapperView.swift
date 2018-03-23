//
//  AudioRoutingWrapperView.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 3/23/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import AVKit
import MediaPlayer

class AudioRoutingWrapperView: UIView {
    var routingView: UIView = {
        var view: UIView! = nil
        if #available(iOS 11.0, *) {
            view = AVRoutePickerView()
        } else {
            let volumeView = MPVolumeView()
            volumeView.showsVolumeSlider = false
            volumeView.showsRouteButton = true
            volumeView.sizeToFit()
            view = volumeView
        }
        return view
    }()
    
    override var frame: CGRect {
        didSet {
            self.routingView.frame = self.bounds
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    init() {
        super.init(frame: CGRect.zero)
        self.setup()
    }

    func setup() {
        self.addSubview(self.routingView)
        self.routingView.frame = self.bounds
        self.isUserInteractionEnabled = true
        print("DEANDEBUG routing view setup finished")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("DEANDEBUG did touch routing button")
    }
}
