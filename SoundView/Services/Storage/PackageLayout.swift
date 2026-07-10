import Foundation

/// Relative layout of a single `.soundview` package directory.
/// All names are package-relative so packages remain portable across devices / iCloud.
enum PackageLayout {
    static let packageExtension = "soundview"
    static let packagesDirectoryName = "Packages"
    static let manifestFileName = "manifest.json"
    static let mixFileName = "mix.json"
    static let stemsDirectoryName = "stems"
    static let originalBaseName = "original"

    /// Temporary suffix while an import is still writing (not listed as a song).
    static let importingSuffix = ".importing"

    static func packageFolderName(id: String) -> String {
        "\(id).\(packageExtension)"
    }

    static func packageURL(root: URL, id: String) -> URL {
        root
            .appendingPathComponent(packagesDirectoryName, isDirectory: true)
            .appendingPathComponent(packageFolderName(id: id), isDirectory: true)
    }

    static func importingPackageURL(root: URL, id: String) -> URL {
        root
            .appendingPathComponent(packagesDirectoryName, isDirectory: true)
            .appendingPathComponent(packageFolderName(id: id) + importingSuffix, isDirectory: true)
    }

    static func manifestURL(packageURL: URL) -> URL {
        packageURL.appendingPathComponent(manifestFileName, isDirectory: false)
    }

    static func mixURL(packageURL: URL) -> URL {
        packageURL.appendingPathComponent(mixFileName, isDirectory: false)
    }

    static func stemsDirectoryURL(packageURL: URL) -> URL {
        packageURL.appendingPathComponent(stemsDirectoryName, isDirectory: true)
    }

    static func originalURL(packageURL: URL, fileName: String) -> URL {
        packageURL.appendingPathComponent(fileName, isDirectory: false)
    }

    static func stemURL(packageURL: URL, fileName: String) -> URL {
        stemsDirectoryURL(packageURL: packageURL).appendingPathComponent(fileName, isDirectory: false)
    }

    /// Stable original file name from source extension.
    static func originalFileName(forSourceExtension ext: String) -> String {
        let clean = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let safe = clean.isEmpty ? "bin" : clean
        return "\(originalBaseName).\(safe)"
    }
}
