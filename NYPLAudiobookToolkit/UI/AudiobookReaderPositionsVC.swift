//
//  AudiobookReaderPositionsVC.swift
//  
//
//  Created by Ernest Fan on 2022-10-11.
//

import UIKit

protocol AudiobookReaderPositionSelectionDelegate: AnyObject {
  func didSelectTOC(_ spineElement: SpineElement)
  func didSelectBookmark(_ bookmark: NYPLAudiobookBookmark)
}

public class AudiobookReaderPositionsVC: UIViewController {
  private let tableView: UITableView!
  private let segmentedControl: UISegmentedControl!
  private var bookmarksRefreshControl: UIRefreshControl?
  
  private lazy var noBookmarksLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.textAlignment = .center
    return label
  }()
  
  private var bookmarksBusinessLogic: NYPLAudiobookBookmarking?
  private var tocProvider: AudiobookTableOfContentsProviding?
  weak var selectionDelegate: AudiobookReaderPositionSelectionDelegate?
  
  private enum Tab: Int {
    case toc = 0
    case bookmarks
  }
  
  private var currentTab: Tab {
    return Tab(rawValue: segmentedControl.selectedSegmentIndex) ?? .toc
  }
  
  private let segmentControlSpacing: CGFloat = 10.0
  
  // MARK: - init
  
  init(bookmarksBusinessLogic: NYPLAudiobookBookmarking?,
       tocProvider: AudiobookTableOfContentsProviding?) {
    segmentedControl = UISegmentedControl(items: [NSLocalizedString("Contents",
                                                                    comment: "Present the table of contents of this audiobook"),
                                                  NSLocalizedString("Bookmarks",
                                                                    comment: "Present the bookmarks of this audiobook")])
    tableView = UITableView()
    
    self.bookmarksBusinessLogic = bookmarksBusinessLogic
    self.tocProvider = tocProvider
    
    super.init(nibName: nil, bundle: nil)
    
    self.tocProvider?.delegate = self
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ViewController LifeCycle
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    
    tableView.dataSource = self
    tableView.delegate = self
    
    tableView.register(AudiobookTrackTableViewCell.self, forCellReuseIdentifier: AudiobookTrackTableViewCell.cellIdentifier)
    tableView.register(AudiobookBookmarkTableViewCell.self, forCellReuseIdentifier: AudiobookBookmarkTableViewCell.cellIdentifier)
    
    segmentedControl.selectedSegmentIndex = currentTab.rawValue
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // Voice Over for current playing TOC item
    if currentTab == .toc,
       let index = tocProvider?.currentSpineIndex() {
      tableView.reloadData()
      if tableView.numberOfRows(inSection: 0) > index {
        let indexPath = IndexPath(row: index, section: 0)
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .top)
        announceTrackIfNeeded(track: indexPath)
      }
    }
  }
  
  // MARK: - UI configuration
  
  private func setupUI() {
    view.addSubview(segmentedControl)
    segmentedControl.autoSetDimension(.height, toSize: 30.0)
    segmentedControl.autoSetDimension(.width, toSize: 350.0, relation: .lessThanOrEqual)
    segmentedControl.autoPinEdge(toSuperviewSafeArea: .top, withInset: segmentControlSpacing)
    segmentedControl.autoAlignAxis(toSuperviewAxis: .vertical)
    segmentedControl.addTarget(self, action: #selector(didSelectSegment(_:)), for: .valueChanged)
    
    view.addSubview(tableView)
    tableView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
    tableView.autoPinEdge(.top, to: .bottom, of: segmentedControl, withOffset: segmentControlSpacing)
    
    let defaultNoBookmarksText = NSLocalizedString("There are no bookmarks for this book.",
                                                   comment: "Text showing in bookmarks view when there are no bookmarks")
    
    noBookmarksLabel.text = bookmarksBusinessLogic?.noBookmarksText ?? defaultNoBookmarksText
    view.insertSubview(noBookmarksLabel, belowSubview: tableView)
    noBookmarksLabel.autoCenterInSuperview()
    noBookmarksLabel.autoSetDimension(.width, toSize: 250)
    
    updateColor()
  }
  
  private func updateColor() {
    view.backgroundColor = NYPLColor.primaryBackgroundColor
    tableView.backgroundColor = NYPLColor.primaryBackgroundColor
    noBookmarksLabel.textColor = NYPLColor.disabledFieldTextColor
  }
  
  private func configRefreshControl() {
    switch currentTab {
    case .toc:
      if let refreshControl = bookmarksRefreshControl, tableView.subviews.contains(refreshControl) {
        refreshControl.removeFromSuperview()
      }
    case .bookmarks:
      if bookmarksBusinessLogic?.shouldAllowRefresh ?? false {
        let refreshCtrl = UIRefreshControl()
        bookmarksRefreshControl = refreshCtrl
        refreshCtrl.addTarget(self,
                              action: #selector(userDidRefreshBookmarks(with:)),
                              for: .valueChanged)
        tableView.addSubview(refreshCtrl)
      }
    }
  }
  
  // MARK: - Helper
  
  @objc func didSelectSegment(_ segmentedControl: UISegmentedControl) {
    tableView.reloadData()

    configRefreshControl()

    switch currentTab {
    case .toc:
      if tableView.isHidden {
        tableView.isHidden = false
      }
    case .bookmarks:
      tableView.isHidden = (bookmarksBusinessLogic?.bookmarksCount == 0)
      if bookmarksBusinessLogic == nil {
        tableView.isHidden = true
      }
    }
  }
  
  @objc(userDidRefreshBookmarksWith:)
  private func userDidRefreshBookmarks(with refreshControl: UIRefreshControl) {
    // Sanity check
    guard let bookmarksBusinessLogic = bookmarksBusinessLogic else {
      return
    }

    bookmarksBusinessLogic.syncBookmarks(completion: { success in
      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          return
        }
        
        self.tableView.reloadData()
        self.bookmarksRefreshControl?.endRefreshing()
        if !success {
          let alert = UIAlertController(title: NSLocalizedString("Error Syncing Bookmarks",
                                                                 comment: "Title for sync failure alert"),
                                        message: NSLocalizedString("There was an error syncing bookmarks to the server. Ensure your device is connected to the internet or try again later.",
                                                                   comment: "Error message for bookmark sync error"),
                                        preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
          self.present(alert, animated: true)
        }
      }
    })
  }
  
  private func announceTrackIfNeeded(track: IndexPath) {
    if UIAccessibility.isVoiceOverRunning {
      let cell = tableView.cellForRow(at: track)
      let accessibleString = NSLocalizedString("Currently Playing: %@",
                                               bundle: Bundle.audiobookToolkit()!,
                                               value: "Currently Playing: %@",
                                               comment: "Announce which track is highlighted in the table of contents.")
      if let text = cell?.textLabel?.text {
        UIAccessibility.post(notification: .screenChanged, argument: String(format: accessibleString, text))
      }
    }
  }
}

// MARK: - UITableViewDataSource

extension AudiobookReaderPositionsVC: UITableViewDataSource {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch currentTab {
    case .toc:
      return tocProvider?.tocCount ?? 0
    case .bookmarks:
      return bookmarksBusinessLogic?.bookmarksCount ?? 0
    }
  }
  
  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch currentTab {
    case .toc:
      let cell = tableView.dequeueReusableCell(withIdentifier: AudiobookTrackTableViewCell.cellIdentifier,
                                               for: indexPath)
      if let cell = cell as? AudiobookTrackTableViewCell,
         let spineElement = tocProvider?.spineElement(for: indexPath.row) {
        cell.configure(for:spineElement)
      }
      return cell
    case .bookmarks:
      let cell = tableView.dequeueReusableCell(withIdentifier: AudiobookBookmarkTableViewCell.cellIdentifier,
                                               for: indexPath)
      if let cell = cell as? AudiobookBookmarkTableViewCell,
         let bizLogic = bookmarksBusinessLogic,
         let bookmark = bizLogic.bookmark(at: indexPath.row) {
        let shouldDisplayChapter = bizLogic.bookmarkIsFirstInChapter(bookmark)
        cell.configure(for: bookmark, shouldDisplayChapter: shouldDisplayChapter)
      }
      return cell
    }
  }
  
  public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    switch currentTab {
    case .toc:
      return false
    case .bookmarks:
      return true
    }
  }
  
  public func tableView(_ tableView: UITableView,
                        commit editingStyle: UITableViewCell.EditingStyle,
                        forRowAt indexPath: IndexPath) {
    switch currentTab {
    case .toc:
      break;
    case .bookmarks:
      guard editingStyle == .delete else {
        return
      }
      
      if bookmarksBusinessLogic?.deleteAudiobookBookmark(at: indexPath.row) ?? false {
        tableView.deleteRows(at: [indexPath], with: .fade)
      }
    }
  }
}

// MARK: - UITableViewDelegate

extension AudiobookReaderPositionsVC: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    defer {
      tableView.deselectRow(at: indexPath, animated: true)
    }

    switch currentTab {
    case .toc:
      if let spineElement = tocProvider?.spineElement(for: indexPath.row) {
        selectionDelegate?.didSelectTOC(spineElement)
      }
    case .bookmarks:
      if let bookmark = bookmarksBusinessLogic?.bookmark(at: indexPath.row) {
        selectionDelegate?.didSelectBookmark(bookmark)
      }
    }
  }
  
  public func tableView(_ tableView: UITableView,
                        editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    switch currentTab {
    case .toc:
      return .none
    case .bookmarks:
      return .delete
    }
  }
  
  public func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
    switch currentTab {
    case .toc:
      return
    case .bookmarks:
      if let bizLogic = bookmarksBusinessLogic,
         bizLogic.bookmarksCount == 0 {
        didSelectSegment(segmentedControl)
      }
    }
  }
}

// MARK: - AudiobookTableOfContentsUpdating

extension AudiobookReaderPositionsVC: AudiobookTableOfContentsUpdating {
  func audiobookTableOfContentsDidUpdate(for chapterLocation: ChapterLocation?) {
    guard currentTab == .toc else {
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      
      if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
        self.tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .none)
      }
      
      if let chapter = chapterLocation,
         let index = self.tocProvider?.spineIndex(for: chapter) {
        let indexPath = IndexPath(row: index, section: 0)
        self.tableView.reloadRows(at: [indexPath], with: .none)
      } else {
        self.tableView.reloadData()
      }
    }
  }
}
