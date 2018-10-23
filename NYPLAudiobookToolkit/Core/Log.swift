import Foundation

@objc public enum LogLevel: Int {
    case debug
    case info
    case warn
    case error
}

final class Log {

    fileprivate class func levelToString(_ level: LogLevel) -> String {
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warn:
            return "WARNING"
        case .error:
            return "ERROR"
        }
    }
    
    class func log(_ level: LogLevel, _ tag: String, _ message: String, error: Error? = nil) {
        #if DEBUG
        let shouldLog = true
        #else
        let shouldLog = level != .debug
        #endif

        if shouldLog {
            NSLog("[\(levelToString(level))] \(tag): \(message)\(error == nil ? "" : "\n\(error!)")")
        }
    }

    class func debug(_ tag: String, _ message: String, error: Error? = nil) {
        log(.debug, tag, message, error: error)
    }

    class func info(_ tag: String, _ message: String, error: Error? = nil) {
        log(.info, tag, message, error: error)
    }

    class func warn(_ tag: String, _ message: String, error: Error? = nil) {
        log(.warn, tag, message, error: error)
    }

    class func error(_ tag: String, _ message: String, error: Error? = nil) {
        log(.error, tag, message, error: error)
    }
}
