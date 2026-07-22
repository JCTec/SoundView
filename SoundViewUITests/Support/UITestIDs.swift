import Foundation

/// Mirror of app `A11yID` for UI test targets (cannot import app types freely in all configs).
enum UITestIDs {
    enum Library {
        static let screen = "library.screen"
        static let list = "library.list"
        static let importButton = "library.import"
        static let recordButton = "library.record"
        static let emptyState = "library.empty"
        static let sidebar = "library.sidebar"
        static func row(_ id: String) -> String { "library.row.\(id)" }
    }

    enum Stem {
        static let screen = "stem.screen"
        static let desk = "stem.desk"
        static let export = "stem.export"
        static let exportSheet = "stem.exportSheet"
        static let exportRun = "stem.exportRun"
        static let exportShare = "stem.exportShare"
        static func exportOption(_ id: String) -> String { "stem.exportOption.\(id)" }
        static func laneExport(_ id: String) -> String { "stem.laneExport.\(id)" }
    }

    enum About {
        static let screen = "about.screen"
        static let open = "about.open"
    }

    enum Recorder {
        static let screen = "recorder.screen"
        static let stop = "recorder.stop"
    }

    enum Separation {
        static let screen = "separation.screen"
        static let cancel = "separation.cancel"
        static let installModel = "separation.installModel"
    }

    enum QualityPicker {
        static let picker = "quality.picker"
        /// `raw` is `SeparationQuality.rawValue` (e.g. "standard", "highQuality").
        static func option(_ raw: String) -> String { "quality.\(raw)" }
    }

    enum Root {
        static let compactStack = "root.compactStack"
        static let splitDesk = "root.splitDesk"
    }
}
