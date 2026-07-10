import SwiftUI

/// Human sentence for iCloud / local state — never a filesystem path.
struct SVSyncStatusLine: View {
    let status: SyncStatus

    var body: some View {
        Text(status.sentence)
            .svCaption()
            .accessibilityLabel(status.sentence)
            .accessibilityIdentifier(A11yID.Library.syncStatus)
    }
}

enum SyncStatus: Equatable, Sendable {
    case syncedWithiCloud
    case uploading
    case offline
    /// Local-only library (iCloud unavailable). Platform-specific copy.
    case onThisDevice
    case separating(progress: Double)

    var sentence: String {
        switch self {
        case .syncedWithiCloud:
            return "Synced with iCloud"
        case .uploading:
            return "Uploading to iCloud…"
        case .offline:
            return "Changes will sync when you're back online"
        case .onThisDevice:
            #if os(macOS)
            return "On this Mac"
            #elseif os(iOS)
            return "On this iPhone"
            #else
            return "On this device"
            #endif
        case .separating(let progress):
            let percent = Int((progress * 100).rounded())
            return "Separating · \(percent)%"
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        SVSyncStatusLine(status: .syncedWithiCloud)
        SVSyncStatusLine(status: .separating(progress: 0.4))
    }
    .padding()
    .background(Color.sv.canvas)
}
