import Foundation
import NYPLUtilities

public final class NYPLAudiobookBookmarkFactory {
  public class func parseLocatorString(
    _ selectorValueEscJSON: String) -> (title: String?, part: UInt, chapter: UInt, audiobookId: String, duration: Double, time: Double)? {
      
      // Convert string to JSON object
      guard
        let selectorValueData = selectorValueEscJSON.data(using: String.Encoding.utf8),
        let selectorValueJSON = (try? JSONSerialization.jsonObject(with: selectorValueData)) as? [String: Any]
      else {
        ATLog(.error, "Error serializing locator. SelectorValue=\(selectorValueEscJSON)")
        return nil
      }

      // Extract data from JSON
      guard
        let part = selectorValueJSON[NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorPartKey] as? UInt,
        let chapter = selectorValueJSON[NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorChapterKey] as? UInt,
        let audiobookId = selectorValueJSON[NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorBookIDKey] as? String,
        let duration = selectorValueJSON[NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorDurationKey] as? Double,
        let time = selectorValueJSON[NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorOffsetKey] as? Double
      else {
        ATLog(.error, "Locator does not contain required value. SelectorValue=\(selectorValueEscJSON)")
        return nil
      }
    
      let title = selectorValueJSON[NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorTitleKey] as? String
      
      return (title: title, part: part, chapter: chapter, audiobookId: audiobookId, duration: duration, time: time)
  }
  
  // Create a locator string to be store as the selector value of a bookmark
  public class func makeLocatorString(title: String,
                                      part: Int,
                                      chapter: Int,
                                      audiobookId: String,
                                      duration: TimeInterval,
                                      time: TimeInterval) -> String {
    let newPart = part >= 0 ? part : 0
    let newChapter = chapter >= 0 ? chapter : 0
    let newDuration = duration >= 0.0 ? duration : TimeInterval(0)
    let newTime = time >= 0.0 ? time : TimeInterval(0)
    
    return """
    {
      "\(NYPLBookmarkSpec.Target.Selector.Value.locatorTypeKey)": "\(NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorTypeValue)",
      "\(NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorTitleKey)": "\(title)",
      "\(NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorPartKey)": \(newPart),
      "\(NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorChapterKey)": \(newChapter),
      "\(NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorBookIDKey)": "\(audiobookId)",
      "\(NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorDurationKey)": \(newDuration),
      "\(NYPLBookmarkSpec.Target.Selector.Value.audiobookLocatorOffsetKey)": \(newTime)
    }
    """
  }
}
