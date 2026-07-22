import Foundation

/// Accessibility identifiers — mirrored in UITest robots (1:1).
enum A11yID {
    enum Root {
        static let compactStack = "root.compactStack"
        static let splitDesk = "root.splitDesk"
    }

    enum Library {
        static let screen = "library.screen"
        static let list = "library.list"
        static let importButton = "library.import"
        static let recordButton = "library.record"
        static let emptyState = "library.empty"
        static let syncStatus = "library.sync"
        static let sidebar = "library.sidebar"
        static func row(_ id: String) -> String { "library.row.\(id)" }
        static func stemJump(_ id: String) -> String { "library.stemJump.\(id)" }
    }

    enum Separation {
        static let screen = "separation.screen"
        static let cancel = "separation.cancel"
        static let progress = "separation.progress"
        static let installModel = "separation.installModel"
    }

    enum QualityPicker {
        static let picker = "quality.picker"
        static func option(_ quality: SoundView.SeparationQuality) -> String { "quality.\(quality.rawValue)" }
    }

    enum Stem {
        static let screen = "stem.screen"
        static let desk = "stem.desk"
        static let export = "stem.export"
        static func lane(_ id: String) -> String { "stem.lane.\(id)" }
        static func laneExport(_ id: String) -> String { "stem.laneExport.\(id)" }
        static let exportSheet = "stem.exportSheet"
        static let exportRun = "stem.exportRun"
        static let exportShare = "stem.exportShare"
        static func exportOption(_ id: String) -> String { "stem.exportOption.\(id)" }
    }

    enum Recorder {
        static let screen = "recorder.screen"
        static let recordToggle = "recorder.toggle"
        static let stop = "recorder.stop"
    }

    enum About {
        static let screen = "about.screen"
        static let open = "about.open"
    }

    enum Transport {
        static let playPause = "transport.playPause"
        static let skipBack = "transport.skipBack"
        static let skipForward = "transport.skipForward"
    }

    enum ModePicker {
        static let picker = "stemMode.picker"
        static func option(_ mode: SoundView.StemMode) -> String { "stemMode.\(mode.rawValue)" }
    }
}
