import Foundation

/// Thin NSFileCoordinator wrappers — required for iCloud-safe package I/O.
enum CoordinatedFileIO {
    static func readData(at url: URL) throws -> Data {
        var coordinatorError: NSError?
        var readError: Error?
        var data: Data?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                data = try Data(contentsOf: readURL)
            } catch {
                readError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let readError { throw readError }
        guard let data else {
            throw FileStoreError.ioFailed("Could not read \(url.lastPathComponent)")
        }
        return data
    }

    static func writeData(_ data: Data, to url: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            writingItemAt: url,
            options: [.forReplacing],
            error: &coordinatorError
        ) { writeURL in
            do {
                try data.write(to: writeURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let writeError { throw writeError }
    }

    static func createDirectory(at url: URL, fileManager: FileManager = .default) throws {
        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            writingItemAt: url,
            options: [.forReplacing],
            error: &coordinatorError
        ) { writeURL in
            do {
                try fileManager.createDirectory(at: writeURL, withIntermediateDirectories: true)
            } catch {
                writeError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let writeError { throw writeError }
    }

    /// Copy that preserves iCloud intent: write into destination via coordinator.
    static func copyItem(from source: URL, to destination: URL, fileManager: FileManager = .default) throws {
        var coordinatorError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            readingItemAt: source,
            options: [],
            writingItemAt: destination,
            options: [.forReplacing],
            error: &coordinatorError
        ) { readURL, writeURL in
            do {
                if fileManager.fileExists(atPath: writeURL.path) {
                    try fileManager.removeItem(at: writeURL)
                }
                try fileManager.copyItem(at: readURL, to: writeURL)
            } catch {
                copyError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
    }

    static func moveItem(from source: URL, to destination: URL, fileManager: FileManager = .default) throws {
        var coordinatorError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            writingItemAt: source,
            options: [.forMoving],
            writingItemAt: destination,
            options: [.forReplacing],
            error: &coordinatorError
        ) { fromURL, toURL in
            do {
                if fileManager.fileExists(atPath: toURL.path) {
                    try fileManager.removeItem(at: toURL)
                }
                try fileManager.moveItem(at: fromURL, to: toURL)
            } catch {
                moveError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let moveError { throw moveError }
    }

    static func removeItem(at url: URL, fileManager: FileManager = .default) throws {
        var coordinatorError: NSError?
        var removeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            writingItemAt: url,
            options: [.forDeleting],
            error: &coordinatorError
        ) { deleteURL in
            do {
                if fileManager.fileExists(atPath: deleteURL.path) {
                    try fileManager.removeItem(at: deleteURL)
                }
            } catch {
                removeError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let removeError { throw removeError }
    }
}
