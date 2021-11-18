import Foundation

public typealias LogHandler = (LogLevel, String, NSError?) -> ()

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

public func ATLog(
    file: String = #file,
    line: Int = #line,
    _ level: LogLevel,
    _ message: String,
    error: Error? = nil)
{
    let url = URL(fileURLWithPath: file)
    let filename = url.lastPathComponent
    let logOutput = "NYPLAudiobookToolkit: \(filename):\(line): \(message)"

    if level != .debug {
        sharedLogHandler?(level, logOutput, error as NSError?)
    }
}
