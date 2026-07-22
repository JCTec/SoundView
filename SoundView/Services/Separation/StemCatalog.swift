import Foundation

/// Canonical stem identities used by Demucs-style models and UI lanes.
enum StemCatalog {
    /// Full 6-stem HTDemucs-6s set (matches typical Python demucs `htdemucs_6s` output).
    static let sixStemNames = ["Vocals", "Drums", "Bass", "Guitar", "Piano", "Other"]

    /// Classic 4-stem HTDemucs set.
    static let fourStemNames = ["Vocals", "Drums", "Bass", "Other"]

    static let twoStemNames = ["Vocals", "Accompaniment"]

    /// File-safe stem keys used under `stems/` and in bundled reference packs.
    static func fileKey(forDisplayName name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }

    static func stemFileName(index: Int, displayName: String) -> String {
        let order = String(format: "%02d", index)
        return "\(order)-\(fileKey(forDisplayName: displayName)).wav"
    }

    /// Names requested for a product stem mode.
    static func names(for mode: StemMode) -> [String] {
        switch mode {
        case .two:
            return twoStemNames
        case .four:
            return fourStemNames
        case .six, .max:
            return sixStemNames
        }
    }

    /// Map a 6-stem pack down to the requested mode (sum companions into Other / Accompaniment).
    static func reduceSixStemKeys(for mode: StemMode) -> [String] {
        // Keys match bundled `Idilio-stems/*.wav` basenames without extension.
        switch mode {
        case .two:
            return ["vocals", "accompaniment"] // accompaniment built by summing non-vocals
        case .four:
            return ["vocals", "drums", "bass", "other"] // other may include guitar+piano+other
        case .six, .max:
            return ["vocals", "drums", "bass", "guitar", "piano", "other"]
        }
    }

    static func displayName(forFileKey key: String) -> String {
        switch key {
        case "vocals": return "Vocals"
        case "drums": return "Drums"
        case "bass": return "Bass"
        case "guitar": return "Guitar"
        case "piano": return "Piano"
        case "other": return "Other"
        case "accompaniment": return "Accompaniment"
        default: return key.capitalized
        }
    }
}
