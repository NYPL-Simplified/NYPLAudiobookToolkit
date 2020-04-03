class DateUtils {
    class func parseDate(_ str: String) -> Date? {
        let date: Date?
        if #available(iOS 10.0, *) {
            let formatter = ISO8601DateFormatter()
            date = formatter.date(from: str)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            date = formatter.date(from: str)
        }
        return date
    }
}
