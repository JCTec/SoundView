import Foundation

/// Where packages live and how to describe that location to humans (never a path).
struct StorageRoot: Sendable, Equatable {
    enum Kind: String, Sendable, Equatable {
        case iCloud
        case local
    }

    /// Absolute root that contains `Packages/`. Not for UI.
    let url: URL
    let kind: Kind

    /// Product copy — Files / Settings style, never a filesystem path.
    var displaySentence: String {
        switch kind {
        case .iCloud:
            return "SoundView in iCloud Drive"
        case .local:
            return SyncStatus.onThisDevice.sentence
        }
    }

    var defaultSyncStatus: SyncStatus {
        switch kind {
        case .iCloud:
            return .syncedWithiCloud
        case .local:
            return .onThisDevice
        }
    }
}

/// Resolves the package root: iCloud ubiquity container when available, else local app support.
/// Not `Sendable` — `FileManager` is used only during short-lived resolution on the caller’s actor.
struct StorageRootResolver: @unchecked Sendable {
    let ubiquityContainerIdentifier: String?
    /// Shared `FileManager` is thread-safe for the operations we use (directory create / ubiquity URL).
    nonisolated(unsafe) let fileManager: FileManager

    init(
        ubiquityContainerIdentifier: String? = "iCloud.com.soundview.app",
        fileManager: FileManager = .default
    ) {
        self.ubiquityContainerIdentifier = ubiquityContainerIdentifier
        self.fileManager = fileManager
    }

    /// Prefer iCloud Drive container Documents so packages appear under
    /// **iCloud Drive → SoundView**. Fall back to Application Support when
    /// iCloud is off, unavailable, or the container is not provisioned (Simulator).
    func resolve() throws -> StorageRoot {
        if let identifier = ubiquityContainerIdentifier,
           let container = fileManager.url(forUbiquityContainerIdentifier: identifier) {
            let documents = container.appendingPathComponent("Documents", isDirectory: true)
            try ensureDirectory(documents)
            let packages = documents.appendingPathComponent(
                PackageLayout.packagesDirectoryName,
                isDirectory: true
            )
            try ensureDirectory(packages)
            // Keep an empty placeholder so the folder is visible in Files.
            try ensureDirectory(documents)
            return StorageRoot(url: documents, kind: .iCloud)
        }

        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appRoot = support.appendingPathComponent("SoundView", isDirectory: true)
        try ensureDirectory(appRoot)
        let packages = appRoot.appendingPathComponent(
            PackageLayout.packagesDirectoryName,
            isDirectory: true
        )
        try ensureDirectory(packages)
        return StorageRoot(url: appRoot, kind: .local)
    }

    /// Fixed root for unit tests (never touches real iCloud).
    static func testing(root: URL, fileManager: FileManager = .default) throws -> StorageRoot {
        let packages = root.appendingPathComponent(
            PackageLayout.packagesDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: packages, withIntermediateDirectories: true)
        return StorageRoot(url: root, kind: .local)
    }

    private func ensureDirectory(_ url: URL) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw FileStoreError.rootNotDirectory(url.lastPathComponent)
            }
            return
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
