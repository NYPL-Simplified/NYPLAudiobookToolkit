import Foundation

class DateUtils {
    class func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: str)
        return date
    }
}
