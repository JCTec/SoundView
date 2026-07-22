import Foundation
import os

/// Appends log lines to a plain-text file in the app's Documents directory.
///
/// This is the retrieval path when `os_log` streaming isn't handy — the file is
/// pullable from a device (`xcrun devicectl device copy from …`) or via the Files
/// app (file sharing is enabled), and it survives across launches so the run that
/// crashed is still on disk afterward. A second backend proving the point of the
/// swappable design: added with zero changes to any call site.
final class FileLogSink: LogSink, @unchecked Sendable {
    let url: URL
    private let lock = OSAllocatedUnfairLock<Void>(initialState: ())
    // Used only under `lock`; the class is @unchecked Sendable.
    private let timestamp: ISO8601DateFormatter

    init(fileName: String = "soundview.log", directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = base.appendingPathComponent(fileName, isDirectory: false)
        timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func write(_ event: LogEvent) {
        let meta = event.metadata.isEmpty
            ? ""
            : " " + event.metadata.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let line = "\(timestamp.string(from: Date())) "
            + "[\(String(describing: event.level))] \(event.category.rawValue): "
            + "\(event.message)\(meta) (\(event.file):\(event.line))\n"
        guard let data = line.data(using: .utf8) else { return }

        lock.withLock {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
