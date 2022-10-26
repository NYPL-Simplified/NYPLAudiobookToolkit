import Foundation

@objc
public protocol NYPLAudiobookBookmarking {
  var bookmarksCount: Int { get }
  var shouldAllowRefresh: Bool { get }
  var noBookmarksText: String { get }
  
  func bookmarkExisting(at location: ChapterLocation) -> NYPLAudiobookBookmark?
  func bookmark(at index: Int) -> NYPLAudiobookBookmark?
  func bookmarkIsFirstInChapter(_ bookmark: NYPLAudiobookBookmark) -> Bool
  func addAudiobookBookmark(_ chapterLocation: ChapterLocation)
  func deleteAudiobookBookmark(at index: Int) -> Bool
  func deleteAudiobookBookmark(_ bookmark: NYPLAudiobookBookmark)
  func syncBookmarks(completion: @escaping (_ success: Bool) -> ())
}
