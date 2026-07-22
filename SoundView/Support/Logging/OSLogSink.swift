import Foundation
import os

/// Default backend: Apple's unified logging (`os.Logger`). Visible live in
/// Console.app or `log stream --predicate 'subsystem == "com.soundview.app"'`,
/// and captured in device sysdiagnoses — no debugger attached needed.
struct OSLogSink: LogSink {
    static let subsystem = "com.soundview.app"

    func write(_ event: LogEvent) {
        let logger = Logger(subsystem: Self.subsystem, category: event.category.rawValue)
        let suffix = event.metadata.isEmpty
            ? ""
            : " · " + event.metadata.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
        let line = "\(event.message)\(suffix) [\(event.file):\(event.line)]"
        // Values are our own diagnostics (no user audio/PII) — log as public.
        switch event.level {
        case .debug: logger.debug("\(line, privacy: .public)")
        case .info: logger.info("\(line, privacy: .public)")
        case .notice: logger.notice("\(line, privacy: .public)")
        case .warning: logger.warning("\(line, privacy: .public)")
        case .error: logger.error("\(line, privacy: .public)")
        case .fault: logger.fault("\(line, privacy: .public)")
        }
    }
}

/// Fans one event out to several sinks — the seam for *adding* a log system
/// (e.g. keep `os_log` and also ship to a file/remote) without changing callers:
/// `Log.configure(sink: CompositeLogSink([OSLogSink(), FileLogSink(…)]))`.
struct CompositeLogSink: LogSink {
    let sinks: [any LogSink]

    init(_ sinks: [any LogSink]) { self.sinks = sinks }

    func write(_ event: LogEvent) {
        for sink in sinks { sink.write(event) }
    }
}
