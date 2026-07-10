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

struct SettingsPlaceholderView: View {
    @Bindable var environment: AppEnvironment

    var body: some View {
        Form {
            Text(environment.storageDisplaySentence)
                .svCaption()
            Text("Storage location is never shown as a raw path.")
                .svCaption()
        }
        .frame(width: 360, height: 120)
        .padding()
        .task {
            await environment.refreshStorageStatus()
        }
    }
}
