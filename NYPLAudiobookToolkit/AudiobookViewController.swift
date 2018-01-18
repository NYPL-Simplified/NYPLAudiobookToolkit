//
//  AudiobookViewController.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/11/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

struct ScrubberUIState {
    let progressPosition: Int
    let gripperRadius: Int
    let leftText: String
    let rightText: String
    var gripperDiameter: Int {
        return gripperRadius * 2
    }
    var gripperPostion: Int {
        return progressPosition - gripperRadius
    }
}

class Scrubber: UIView {
    let barHeight = 4
    var progressBar = UIView()
    let progressBackground = UIView()
    let gripper = UIView()
    let leftLabel = UILabel()
    let rightLabel = UILabel()
    private var states: [ScrubberUIState] = []
    var state: ScrubberUIState = ScrubberUIState(
        progressPosition: 0,
        gripperRadius: 4,
        leftText: "0:00",
        rightText: "5:00"
    ) {
        didSet {
            states.append(self.state)
            self.updateUIWith(self.state)
        }
    }

    var timer: Timer?

    public func play() {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(Scrubber.updateProgress(_:)),
            userInfo: nil,
            repeats:
            true
        )
    }
    
    public func updateUIWith(_ state: ScrubberUIState) {
        self.setNeedsLayout()
    }

    public func pause() {
        self.timer?.invalidate()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    func setup () {
        self.addSubview(self.progressBackground)
        self.progressBackground.layer.cornerRadius = CGFloat(self.barHeight / 2)
        self.progressBackground.backgroundColor = UIColor.lightGray

        self.addSubview(self.progressBar)
        self.progressBar.backgroundColor = UIColor.gray
        self.progressBar.layer.cornerRadius = CGFloat(self.barHeight / 2)

        self.addSubview(self.gripper)
        self.gripper.backgroundColor = UIColor.gray
        self.gripper.layer.cornerRadius = CGFloat(self.state.gripperRadius)
        
        self.addSubview(self.leftLabel)
        self.leftLabel.autoPinEdge(.left, to: .left, of: self)
        self.leftLabel.autoPinEdge(.top, to: .bottom, of: self.gripper)
        
        self.addSubview(self.rightLabel)
        self.rightLabel.autoPinEdge(.right, to: .right, of: self)
        self.rightLabel.autoPinEdge(.top, to: .bottom, of: self.gripper)
    }
    
    override func layoutSubviews() {
        UIView.beginAnimations("layout", context: nil)
        let centerY = self.bounds.height / 2
        self.gripper.frame = CGRect(
            x: CGFloat(self.state.progressPosition),
            y: centerY - CGFloat(self.state.gripperRadius),
            width: CGFloat(self.state.gripperDiameter),
            height: CGFloat(self.state.gripperDiameter)
        )
        self.gripper.layer.cornerRadius = CGFloat(self.state.gripperRadius)
        
        let barPosition =  CGPoint(x: 0, y: centerY - CGFloat(self.barHeight / 2))
        self.progressBackground.frame = CGRect(
            origin: barPosition,
            size: CGSize(width: self.bounds.size.width, height: CGFloat(self.barHeight))
        )
        self.progressBar.frame = CGRect(
            origin: barPosition,
            size: CGSize(width: CGFloat(self.state.progressPosition), height: CGFloat(self.barHeight))
        )
        self.leftLabel.text = self.state.leftText
        self.rightLabel.text = self.state.rightText
        UIView.commitAnimations()
    }
    
    @objc func updateProgress(_ sender: Any) {
        var newWidth = 0
        if self.progressBar.frame.size.width <= self.frame.size.width {
            newWidth = self.state.progressPosition + 3
        }
        self.state = ScrubberUIState(
            progressPosition: newWidth,
            gripperRadius: 4,
            leftText: self.state.leftText,
            rightText: self.state.rightText
        )

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let postion = touch.location(in: self)
            self.state = ScrubberUIState(
                progressPosition: Int(postion.x),
                gripperRadius: 9,
                leftText: self.state.leftText,
                rightText: self.state.rightText
            )
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let postion = touch.location(in: self)
            self.state = ScrubberUIState(
                progressPosition: Int(postion.x),
                gripperRadius: 9,
                leftText: self.state.leftText,
                rightText: self.state.rightText
            )
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let postion = touch.location(in: self)
            self.state = ScrubberUIState(
                progressPosition: Int(postion.x),
                gripperRadius: 4,
                leftText: self.state.leftText,
                rightText: self.state.rightText
            )
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let postion = touch.location(in: self)
            self.state = ScrubberUIState(
                progressPosition: Int(postion.x),
                gripperRadius: 4,
                leftText: self.state.leftText,
                rightText: self.state.rightText
            )
        }
    }
}

public class AudiobookViewController: UIViewController {
    private var seekBar: Scrubber?
    
    let audiobookMetadata = AudiobookMetadata(title: "Vacationland", authors: ["John Hodgeman"], narrators: ["John Hodgeman"], publishers: ["Random House"], published: Date(), modified: Date(), language: "en")

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.seekBar =  Scrubber(frame: CGRect(origin: self.view.frame.origin, size: CGSize(width: self.view.frame.size.width - 16, height: 10)))
        self.navigationItem.backBarButtonItem?.title = nil
        let bbi = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(AudiobookViewController.tocWasPressed))
        self.navigationItem.rightBarButtonItem = bbi
        self.navigationItem.title = self.audiobookMetadata.title
        self.view.backgroundColor = UIColor.white
        if let bar = self.seekBar {
            self.view.addSubview(bar)
        }
        self.seekBar?.autoPin(toTopLayoutGuideOf: self, withInset: 16)
        self.seekBar?.autoPinEdge(.left, to: .left, of: self.view, withOffset: 8)
        self.seekBar?.autoPinEdge(.right, to: .right, of: self.view, withOffset: -8)
        self.seekBar?.autoSetDimensions(to: CGSize(width: self.view.frame.size.width - 16, height: 18))
        self.seekBar?.play()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc public func tocWasPressed(_ sender: Any) {
        let tbvc = UITableViewController()
        tbvc.tableView.dataSource = self
        self.navigationController?.pushViewController(tbvc, animated: true)
    }
    
    private func imageWithView(inView: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(inView.bounds.size, inView.isOpaque, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let context = UIGraphicsGetCurrentContext() {
            inView.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            return image
        }
        return nil
    }
}

extension AudiobookViewController: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = "Chapter \(indexPath.row)"
        return cell
    }
}
