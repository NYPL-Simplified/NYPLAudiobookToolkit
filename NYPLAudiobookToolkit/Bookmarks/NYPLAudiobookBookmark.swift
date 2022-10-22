import Foundation
import NYPLUtilities

// TODO: Decide if this should be a class or struct when implementation is completed
@objc public final class NYPLAudiobookBookmark: NSObject, NYPLBookmark, Codable {
  public let title: String?
  public let chapter: UInt
  public let part: UInt
  public let duration: TimeInterval
  public let time: TimeInterval
  public let audiobookId: String
  
  public var annotationId: String?
  public let device: String?
  public let creationTime: Date
  
  private enum CodingKeys: String, CodingKey {
    case title, chapter, part, duration, time, audiobookId, annotationId, device, creationTime
  }
  
  // MARK: Init
  
  @objc
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
    /// Correction on negative `duration` and `time` value is being done when
    /// 1. Creating audiobook bookmark
    /// 2. Making locator string for uploading to server
    /// Correction is done in both places to avoid dyssynchronous when bookmark is being uploaded.
    self.duration = duration >= 0.0 ? duration : TimeInterval(0)
    self.time = time >= 0.0 ? time : TimeInterval(0)
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
              time: chapterLocation.playheadOffset,
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
  
  /// Initialize from a dictionary representation, usually derived from
  /// the `NYPLBookRegistry`.
  ///
  /// - Parameter dictionary: Dictionary representation of the bookmark. See
  /// `NYPLBookmarkDictionaryRepresentation` for valid keys.
  @objc public convenience init?(dictionary:NSDictionary) {
    guard let chapter = dictionary[CodingKeys.chapter.rawValue] as? UInt,
          let part = dictionary[CodingKeys.part.rawValue] as? UInt,
          let duration = dictionary[CodingKeys.duration.rawValue] as? TimeInterval,
          let time = dictionary[CodingKeys.time.rawValue] as? TimeInterval,
          let audiobookId = dictionary[CodingKeys.audiobookId.rawValue] as? String,
          let creationTimeInterval = dictionary[CodingKeys.creationTime.rawValue] as? TimeInterval else {
      return nil
    }
    
    self.init(title: dictionary[CodingKeys.title.rawValue] as? String,
              chapter: chapter,
              part: part,
              duration: duration,
              time: time,
              audiobookId: audiobookId,
              annotationId: dictionary[CodingKeys.annotationId.rawValue] as? String,
              device: dictionary[CodingKeys.device.rawValue] as? String,
              creationTime: Date(timeIntervalSince1970: creationTimeInterval))
  }
  
  // MARK: Representation
  
  @objc public var dictionaryRepresentation:NSDictionary {
    let dict: NSMutableDictionary = [
      CodingKeys.chapter.rawValue: self.chapter,
      CodingKeys.part.rawValue: self.part,
      CodingKeys.duration.rawValue: self.duration,
      CodingKeys.time.rawValue: self.time,
      CodingKeys.audiobookId.rawValue: self.audiobookId,
      CodingKeys.creationTime.rawValue: self.creationTime.timeIntervalSince1970,
    ]
    
    if let title = title {
      dict[CodingKeys.title.rawValue] = title
    }
    
    if let annotationId = annotationId {
      dict[CodingKeys.annotationId.rawValue] = annotationId
    }
    
    if let device = device {
      dict[CodingKeys.device.rawValue] = device
    }
    
    return dict
  }
  
  // Serialize the bookmark for posting to server and storing in local storage
  // Note: Unit test for this function is located in Simplified-iOS repo
  // because we need access to NYPLAnnotations class to test it.
  public func serializableRepresentation(forMotivation motivation: NYPLBookmarkSpec.Motivation,
                                         bookID: String) -> [String : Any] {
    let selectorString = NYPLAudiobookBookmarkFactory.makeLocatorString(title: title ?? "",
                                                                        part: part,
                                                                        chapter: chapter,
                                                                        audiobookId: audiobookId,
                                                                        duration: duration,
                                                                        time: time)
    let spec = NYPLBookmarkSpec(id: annotationId,
                                time: creationTime,
                                device: device ?? "",
                                bodyOthers: nil,
                                motivation: motivation,
                                bookID: bookID,
                                selectorValue: selectorString)
    
    return spec.dictionaryForJSONSerialization()
  }
}

public extension NYPLAudiobookBookmark {
  /// Determines if a given chapter location matches the location addressed by this
  /// bookmark. Locations are considered matching if the offset difference is less than 3 seconds.
  /// The 3 seconds difference is only applied when we attempt to create a new bookmark.
  /// Use the =~= operator when we want to know if two existing bookmarks are the same.
  ///
  /// - Complexity: O(*1*).
  ///
  /// - Parameters:
  ///   - locator: The object representing the given location in the audiobook
  ///
  /// - Returns: `true` if the chapter location's position matches the bookmark's.
  func locationMatches(_ location: ChapterLocation) -> Bool {
    guard self.audiobookId == location.audiobookID,
          self.chapter == location.number,
          self.part == location.part,
          self.duration == location.duration else {
      return false
    }
    
    return abs(Float(self.time) - Float(location.playheadOffset)) < 3
  }
  
  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? NYPLAudiobookBookmark else {
      return false
    }

    guard self.audiobookId == other.audiobookId,
          self.chapter == other.chapter,
          self.part == other.part,
          self.duration == other.duration else {
      return false
    }
    
    return Float(self.time) =~= Float(other.time)
  }
}

extension NYPLAudiobookBookmark: Comparable {
  public static func < (lhs: NYPLAudiobookBookmark, rhs: NYPLAudiobookBookmark) -> Bool {
    if lhs.part != rhs.part {
      return lhs.part < rhs.part
    } else if lhs.chapter != rhs.chapter {
      return lhs.chapter < rhs.chapter
    } else {
      return lhs.time < rhs.time
    }
  }
  
  public static func == (lhs: NYPLAudiobookBookmark, rhs: NYPLAudiobookBookmark) -> Bool {
    guard lhs.audiobookId == rhs.audiobookId,
          lhs.chapter == rhs.chapter,
          lhs.part == rhs.part,
          lhs.duration == rhs.duration else {
      return false
    }
    
    return Float(lhs.time) =~= Float(rhs.time)
  }
}

@objc
public extension NYPLAudiobookBookmark {
  @objc func lessThan(_ bookmark: NYPLAudiobookBookmark) -> Bool {
    return self < bookmark
  }
}
