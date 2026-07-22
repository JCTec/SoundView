import Foundation

/// Persists the app's current risky operation so an **OOM / jetsam kill — which
/// leaves no crash log** — can be reconstructed on the next launch. Swappable
/// like `LogSink`; install via `Log.configure(breadcrumbs:…)`.
protocol BreadcrumbStore: Sendable {
    func set(_ crumb: String)
    func clear()
    /// Read the last crumb and clear it (launch-time recovery). `nil` = clean exit.
    func take() -> String?
}

/// File-backed store with an atomic synchronous write, so the crumb is on disk
/// before an abrupt kill can happen.
struct FileBreadcrumbStore: BreadcrumbStore {
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("soundview.breadcrumb", isDirectory: false)
    }

    func set(_ crumb: String) {
        try? Data(crumb.utf8).write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    func take() -> String? {
        guard let data = try? Data(contentsOf: url),
              let crumb = String(data: data, encoding: .utf8) else {
            return nil
        }
        clear()
        return crumb
    }
}
