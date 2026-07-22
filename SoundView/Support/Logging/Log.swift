import Foundation
import os

/// SoundView's logging facade — the single entry point call sites use.
///
/// The concrete backend (`LogSink`) and breadcrumb store are held behind a lock
/// and swapped in one place via `configure`, so adding or replacing a log system
/// (file, remote, analytics, a test spy) never touches a call site:
///
/// ```swift
/// Log.configure(sink: CompositeLogSink([OSLogSink(), MyRemoteSink()]))
/// Log.info(.separation, "started", ["chunks": "40"])
/// ```
///
/// Defaults to `OSLogSink` + `FileBreadcrumbStore`, so logging works before any
/// explicit configuration. Thread-safe (usable from detached separation tasks).
enum Log {
    private struct Config {
        var sink: any LogSink
        var breadcrumbs: any BreadcrumbStore
    }

    private static let state = OSAllocatedUnfairLock<Config>(
        initialState: Config(sink: OSLogSink(), breadcrumbs: FileBreadcrumbStore())
    )

    /// Swap the backend and/or breadcrumb store. Pass only what you want to change.
    static func configure(sink: (any LogSink)? = nil, breadcrumbs: (any BreadcrumbStore)? = nil) {
        state.withLock { config in
            if let sink { config.sink = sink }
            if let breadcrumbs { config.breadcrumbs = breadcrumbs }
        }
    }

    // MARK: - Emit

    static func emit(
        _ level: LogLevel, _ category: LogCategory, _ message: String,
        _ metadata: [String: String] = [:],
        function: String = #function, file: String = #fileID, line: Int = #line
    ) {
        let event = LogEvent(
            level: level, category: category, message: message,
            metadata: metadata, function: function, file: file, line: line
        )
        state.withLock { $0.sink.write(event) }
    }

    static func debug(_ category: LogCategory, _ message: String, _ metadata: [String: String] = [:],
                      function: String = #function, file: String = #fileID, line: Int = #line) {
        emit(.debug, category, message, metadata, function: function, file: file, line: line)
    }
    static func info(_ category: LogCategory, _ message: String, _ metadata: [String: String] = [:],
                     function: String = #function, file: String = #fileID, line: Int = #line) {
        emit(.info, category, message, metadata, function: function, file: file, line: line)
    }
    static func notice(_ category: LogCategory, _ message: String, _ metadata: [String: String] = [:],
                       function: String = #function, file: String = #fileID, line: Int = #line) {
        emit(.notice, category, message, metadata, function: function, file: file, line: line)
    }
    static func warning(_ category: LogCategory, _ message: String, _ metadata: [String: String] = [:],
                        function: String = #function, file: String = #fileID, line: Int = #line) {
        emit(.warning, category, message, metadata, function: function, file: file, line: line)
    }
    static func error(_ category: LogCategory, _ message: String, _ metadata: [String: String] = [:],
                      function: String = #function, file: String = #fileID, line: Int = #line) {
        emit(.error, category, message, metadata, function: function, file: file, line: line)
    }
    static func fault(_ category: LogCategory, _ message: String, _ metadata: [String: String] = [:],
                      function: String = #function, file: String = #fileID, line: Int = #line) {
        emit(.fault, category, message, metadata, function: function, file: file, line: line)
    }

    // MARK: - Breadcrumbs (survive OOM/jetsam kills)

    /// Record the current risky stage. Overwrites the previous crumb.
    static func breadcrumb(_ crumb: String) {
        state.withLock { $0.breadcrumbs.set(crumb) }
    }

    /// Mark the risky work finished cleanly (so launch recovery reports nothing).
    static func clearBreadcrumb() {
        state.withLock { $0.breadcrumbs.clear() }
    }

    /// Call once at launch: if the previous run died mid-operation (no crash log —
    /// classic OOM/jetsam), surface the last stage as a fault so it's diagnosable.
    static func recoverFromUncleanExit() {
        let crumb = state.withLock { $0.breadcrumbs.take() }
        guard let crumb else { return }
        emit(.fault, .lifecycle,
             "Recovered from an unclean exit — last run died mid-operation (likely OOM/jetsam)",
             ["lastStage": crumb])
    }

    // MARK: - Memory

    static func memory() -> [String: String] { MemoryReport.snapshot() }

    /// Merge a memory snapshot into caller metadata (caller keys win on collision).
    static func withMemory(_ metadata: [String: String] = [:]) -> [String: String] {
        metadata.merging(MemoryReport.snapshot()) { current, _ in current }
    }
}
