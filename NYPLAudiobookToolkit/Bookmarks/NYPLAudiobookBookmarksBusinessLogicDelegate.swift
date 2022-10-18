import Foundation

@objc
public protocol NYPLAudiobookBookmarksBusinessLogicDelegate {
  var bookmarksCount: Int { get }
  var shouldAllowRefresh: Bool { get }
  var noBookmarksText: String { get }
  
  func bookmark(at index: Int) -> NYPLAudiobookBookmark?
  func addAudiobookBookmark(_ chapterLocation: ChapterLocation)
  func deleteAudiobookBookmark(at index: Int) -> Bool
  func syncBookmarks(completion: @escaping (_ success: Bool) -> ())
}
