import Foundation
import NYPLUtilities

// TODO: Decide if this should be a class or struct when implementation is completed
public final class NYPLAudiobookBookmark: NYPLBookmark {
  public let title: String?
  public let chapter: UInt
  public let part: UInt
  public let duration: TimeInterval
  public let time: TimeInterval
  public let audiobookId: String
  
  public var annotationId: String?
  public let device: String?
  public let creationTime: Date
  
  // MARK: Init
  
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
  
  // For initializing with ChapterLocation
  public convenience init(chapterLocation: ChapterLocation,
                          device: String? = nil,
                          creationTime: Date) {
    self.init(title: chapterLocation.title,
              chapter: chapterLocation.number,
              part: chapterLocation.part,
              duration: chapterLocation.duration,
              time: chapterLocation.startOffset,
              audiobookId: chapterLocation.audiobookID,
              annotationId: nil,
              device: device,
              creationTime: creationTime)
  }
  
  // For initializing with selector value
  public convenience init?(selectorString: String,
                           annotationId: String? = nil,
                           device: String? = nil,
                           creationTime: Date) {
    guard let tuple = NYPLAudiobookBookmarkFactory.parseLocatorString(selectorString) else {
      return nil
    }
    
    self.init(title: tuple.title,
              chapter: tuple.chapter,
              part: tuple.part,
              duration: tuple.duration,
              time: tuple.time,
              audiobookId: tuple.audiobookId,
              annotationId: annotationId,
              device: device,
              creationTime: creationTime)
  }
  
  // MARK: Serialize
  
  // Serialize the bookmark for posting to server and storing in local storage
  public func serializableRepresentation(forMotivation motivation: NYPLBookmarkSpec.Motivation,
                                         bookID: String) -> [String : Any] {
    // TODO: iOS-444
    return [:]
  }
}
