import Foundation

/// Severity of a log event (maps onto `os_log` levels).
enum LogLevel: Int, Sendable, Comparable, CaseIterable {
    case debug, info, notice, warning, error, fault
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Subsystem area a log event belongs to (the `os_log` category).
enum LogCategory: String, Sendable, CaseIterable {
    case app, lifecycle, separation, coreml, model, export, memory
}

/// One structured log event.
struct LogEvent: Sendable {
    let level: LogLevel
    let category: LogCategory
    let message: String
    let metadata: [String: String]
    let function: String
    let file: String
    let line: Int
}

/// The swappable logging backend. Implement this to route SoundView's logs to a
/// new destination — `os_log`, a file, a remote/analytics service, a test spy —
/// without touching a single call site. Install it via `Log.configure(sink:…)`.
protocol LogSink: Sendable {
    func write(_ event: LogEvent)
}
