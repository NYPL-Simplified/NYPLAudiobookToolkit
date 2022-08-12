import Foundation

public protocol NYPLAudiobookBookmarksBusinessLogicDelegate {
  var bookmarksCount: Int { get }
  
  func bookmark(at index: Int) -> NYPLAudiobookBookmark?
  func addAudiobookBookmark(_ chapterLocation: ChapterLocation)
  func deleteAudiobookBookmark(at index: Int)
  func syncBookmarks(completion: @escaping (_ success: Bool) -> ())
}

// TODO: Decide if this should be a class or struct when implementation is completed
public final class NYPLAudiobookBookmark {
  public let title: String?
  public let chapter: UInt
  public let part: UInt
  public let duration: TimeInterval
  public let time: TimeInterval
  public let audiobookId: String
  
  public var annotationId: String?
  public let device: String?
  public let creationTime: Date
  
  public init(title: String? = nil,
              chapter: UInt,
              part: UInt,
              duration: TimeInterval,
              time: TimeInterval,
              audiobookId: String,
              annotationId: String? = nil,
              device: String? = nil,
              creationTime: Date) {
    self.title = title
    self.chapter = chapter
    self.part = part
    self.duration = duration
    self.time = time
    self.audiobookId = audiobookId
    self.annotationId = annotationId
    self.device = device
    self.creationTime = creationTime
  }
}
