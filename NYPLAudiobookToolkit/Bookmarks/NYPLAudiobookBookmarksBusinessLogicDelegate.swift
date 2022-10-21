import Foundation

@objc
public protocol NYPLAudiobookBookmarksBusinessLogicDelegate {
  var bookmarksCount: Int { get }
  var shouldAllowRefresh: Bool { get }
  var noBookmarksText: String { get }
  
  func bookmarkExisting(at location: ChapterLocation) -> NYPLAudiobookBookmark?
  func bookmark(at index: Int) -> NYPLAudiobookBookmark?
  func addAudiobookBookmark(_ chapterLocation: ChapterLocation) -> Bool
  func deleteAudiobookBookmark(at index: Int) -> Bool
  func deleteAudiobookBookmark(_ bookmark: NYPLAudiobookBookmark) -> Bool
  func syncBookmarks(completion: @escaping (_ success: Bool) -> ())
}
