import Foundation

public protocol NYPLAudiobookBookmarksBusinessLogicDelegate {
  var bookmarksCount: Int { get }
  
  func bookmark(at index: Int) -> NYPLAudiobookBookmark?
  func addAudiobookBookmark(_ chapterLocation: ChapterLocation)
  func deleteAudiobookBookmark(at index: Int)
  func syncBookmarks(completion: @escaping (_ success: Bool) -> ())
}
