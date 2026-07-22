import SwiftUI

/// Resolves live package state so Separation → Stem View updates after real separation.
struct SongDestinationView: View {
    let songID: String
    @Binding var stemMode: StemMode
    @Environment(\.appEnvironment) private var environment
    @State private var song: SongPackage?
    @State private var reloadToken = 0

    var body: some View {
        Group {
            if let song {
                if song.isSeparated {
                    StemView(song: song)
                } else {
                    SeparationView(song: song, mode: $stemMode)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.sv.canvas)
            }
        }
        .task(id: "\(songID)-\(reloadToken)") {
            song = try? await environment.fileStore.song(id: songID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .soundViewPackageDidChange)) { note in
            guard let id = note.userInfo?["id"] as? String, id == songID else { return }
            reloadToken += 1
        }
    }
}

extension Notification.Name {
    static let soundViewPackageDidChange = Notification.Name("soundView.packageDidChange")
}
