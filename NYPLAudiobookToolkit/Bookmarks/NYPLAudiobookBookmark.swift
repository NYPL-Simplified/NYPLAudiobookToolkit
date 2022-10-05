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
    guard let chapter = dictionary[CodingKeys.chapter] as? UInt,
          let part = dictionary[CodingKeys.part] as? UInt,
          let duration = dictionary[CodingKeys.duration] as? TimeInterval,
          let time = dictionary[CodingKeys.time] as? TimeInterval,
          let audiobookId = dictionary[CodingKeys.audiobookId] as? String,
          let creationTime = dictionary[CodingKeys.creationTime] as? Date else {
      return nil
    }
    
    
    self.init(title: dictionary[CodingKeys.title] as? String,
              chapter: chapter,
              part: part,
              duration: duration,
              time: time,
              audiobookId: audiobookId,
              annotationId: dictionary[CodingKeys.annotationId] as? String,
              device: dictionary[CodingKeys.device] as? String,
              creationTime: creationTime)
  }
  
  // MARK: Representation
  
  @objc public var dictionaryRepresentation:NSDictionary {
    let dict: NSMutableDictionary = [
      CodingKeys.chapter: self.chapter,
      CodingKeys.part: self.part,
      CodingKeys.duration: self.duration,
      CodingKeys.time: self.time,
      CodingKeys.audiobookId: self.audiobookId,
      CodingKeys.creationTime: self.creationTime,
    ]
    
    if let title = title {
      dict[CodingKeys.title] = title
    }
    
    if let annotationId = annotationId {
      dict[CodingKeys.annotationId] = annotationId
    }
    
    if let device = device {
      dict[CodingKeys.device] = device
    }
    
    return dict
  }
  
  // Serialize the bookmark for posting to server and storing in local storage
  public func serializableRepresentation(forMotivation motivation: NYPLBookmarkSpec.Motivation,
                                         bookID: String) -> [String : Any] {
    // TODO: iOS-444
    return [:]
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
