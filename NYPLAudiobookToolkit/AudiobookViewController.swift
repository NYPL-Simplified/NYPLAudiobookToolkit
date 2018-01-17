//
//  AudiobookViewController.swift
//  NYPLAudibookKit
//
//  Created by Dean Silfen on 1/11/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit
import PureLayout

class Scrubber: UIView {
    let barHeight = 10
    let gripperHeight = 14
    let progressBar = UIView()
    let progressBackground = UIView()
    let gripper = UIView()

    var timer: Timer?

    func play() {
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    func setup () {
        self.addSubview(self.progressBackground)
        self.progressBackground.layer.borderWidth = 1
        self.progressBackground.layer.cornerRadius = 5
        self.progressBackground.backgroundColor = UIColor.gray

        self.addSubview(self.progressBar)
        self.progressBar.backgroundColor = UIColor.blue
        self.progressBar.layer.cornerRadius = 5
        
        self.addSubview(self.gripper)
        self.gripper.backgroundColor = UIColor.blue
        self.gripper.layer.cornerRadius = 5
        self.gripper.layer.borderWidth = 1
        self.gripper.layer.borderColor = UIColor.gray.cgColor
    }
    
    override func layoutSubviews() {
        self.progressBackground.frame = CGRect(
                x: self.bounds.origin.x,
                y: self.bounds.origin.y,
                width: self.bounds.size.width,
                height: CGFloat(barHeight)
        )

        self.progressBar.frame = CGRect(
            x: self.bounds.origin.x,
            y: self.bounds.origin.y,
            width: self.progressBar.frame.size.width,
            height: CGFloat(barHeight)
        )
        self.gripper.frame = CGRect(
            x: self.progressBar.frame.width - 5,
            y: self.bounds.origin.y / 2,
            width: 10,
            height: CGFloat(gripperHeight)
        )
    }
    
    @objc func updateProgress(_ sender: Any) {
        var newWidth: CGFloat = 0
        if self.progressBar.frame.size.width + 1 < self.frame.size.width {
            newWidth = CGFloat(self.progressBar.frame.size.width + CGFloat(3))
        }
    
        let newFrame = CGRect(
            x: self.progressBar.frame.origin.x,
            y: self.progressBar.frame.origin.y,
            width: CGFloat(newWidth),
            height: CGFloat(barHeight)
        )
        
        self.progressBar.frame = newFrame
        self.setNeedsLayout()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        self.seekBar?.autoPinEdge(.top, to: .top, of: self.view, withOffset: 70)
        self.seekBar?.autoPinEdge(.left, to: .left, of: self.view, withOffset: 8)
        self.seekBar?.autoPinEdge(.right, to: .right, of: self.view, withOffset: -8)
        self.seekBar?.autoSetDimensions(to: CGSize(width: self.view.frame.size.width - 16, height: 14))
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
