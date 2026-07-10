import SwiftUI

/// Size-class switch: compact stack vs regular/large stem desk.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        Group {
            if sizeClass == .compact {
                CompactRootView()
                    .accessibilityIdentifier(A11yID.Root.compactStack)
            } else {
                DeskRootView()
                    .accessibilityIdentifier(A11yID.Root.splitDesk)
            }
        }
        .background(Color.sv.canvas.ignoresSafeArea())
        .environment(\.appEnvironment, environment)
    }
}

/// iPhone / narrow: NavigationStack.
struct CompactRootView: View {
    var body: some View {
        NavigationStack {
            LibraryView()
        }
    }
}

/// iPad / Mac: NavigationSplitView library + desk.
struct DeskRootView: View {
    @State private var selectedSongID: String?
    @State private var selectedStemID: String?

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(
                selectedSongID: $selectedSongID,
                selectedStemID: $selectedStemID
            )
        } detail: {
            StemDeskView(
                songID: selectedSongID,
                focusedStemID: $selectedStemID
            )
        }
    }
}

#Preview("Compact") {
    RootView()
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("Desk") {
    RootView()
        .environment(\.horizontalSizeClass, .regular)
}
