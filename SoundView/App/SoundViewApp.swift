import SwiftUI

@main
struct SoundViewApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appEnvironment, environment)
                .preferredColorScheme(.dark)
                .task {
                    // Logging is configured in AppEnvironment.init (composition root).
                    // Real package on disk (DEBUG) so library testing uses Idilio, not empty demo lists.
                    await environment.seedDevelopmentLibraryIfNeeded()
                    await environment.refreshStorageStatus()
                }
        }
        #if os(macOS)
        .commands {
            MenuCommands()
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsPlaceholderView(environment: environment)
        }
        #endif
    }
}

/// Menu bar hooks (macOS) — shortcuts mirror product keyboard map.
struct MenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {}
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandMenu("Playback") {
            Button("Play/Pause") {}
                .keyboardShortcut(.space, modifiers: [])
            Button("Skip Back 15s") {}
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Skip Forward 15s") {}
                .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        CommandMenu("Stems") {
            Button("Export…") {}
                .keyboardShortcut("e", modifiers: .command)
        }
    }
}

/// macOS Settings hosts the credits + privacy surface (the Demucs attribution
/// and the "audio never leaves this device" promise live in `AboutView`).
struct SettingsPlaceholderView: View {
    @Bindable var environment: AppEnvironment

    var body: some View {
        AboutView()
            .environment(\.appEnvironment, environment)
            .frame(width: 440, height: 560)
            .task {
                await environment.refreshStorageStatus()
            }
    }
}
