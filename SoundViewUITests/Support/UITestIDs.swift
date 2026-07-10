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
    }

    enum Recorder {
        static let screen = "recorder.screen"
        static let stop = "recorder.stop"
    }

    enum Separation {
        static let screen = "separation.screen"
        static let cancel = "separation.cancel"
    }

    enum Root {
        static let compactStack = "root.compactStack"
        static let splitDesk = "root.splitDesk"
    }
}
