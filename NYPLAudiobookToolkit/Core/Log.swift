import Foundation

@objc public enum LogLevel: Int {
    case debug
    case info
    case warn
    case error
}

private func levelToString(_ level: LogLevel) -> String {
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
    
func ATLog(
    file: String = #file,
    line: Int = #line,
    _ level: LogLevel,
    _ message: String,
    error: Error? = nil)
{
    #if DEBUG
    let shouldLog = true
    #else
    let shouldLog = level != .debug
    #endif

    let url = URL(fileURLWithPath: file)
    let filename = url.lastPathComponent

    if shouldLog {
        NSLog("[\(levelToString(level))] \(filename):\(line): \(message)\(error == nil ? "" : "\n\(error!)")")
    }
}
