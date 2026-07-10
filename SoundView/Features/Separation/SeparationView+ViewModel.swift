import Foundation
import Observation

extension SeparationView {
    @Observable
    @MainActor
    final class ViewModel {
        let song: SongPackage
        var mode: StemMode
        private(set) var progress: Double = 0
        private(set) var foundStems: [StemDescriptor] = []
        private(set) var isRunning = false
        private var task: Task<Void, Never>?

        init(song: SongPackage, mode: StemMode) {
            self.song = song
            self.mode = mode
        }

        var progressLabel: String {
            let count = foundStems.count
            let eta = max(1, Int(((1 - progress) * 60).rounded()))
            return "Found \(count) stems so far… · ~\(eta)s left"
        }

        func startDemoProgress() async {
            // Placeholder until StemSeparator is wired — proves UI materialization.
            isRunning = true
            let names = demoNames(for: mode)
            for (index, name) in names.enumerated() {
                guard isRunning else { return }
                try? await Task.sleep(for: .milliseconds(600))
                foundStems.append(
                    StemDescriptor(id: "\(index)", name: name, index: index)
                )
                progress = Double(index + 1) / Double(names.count)
            }
            isRunning = false
        }

        func cancel() {
            isRunning = false
            task?.cancel()
        }

        private func demoNames(for mode: StemMode) -> [String] {
            switch mode {
            case .two: ["Vocals", "Accompaniment"]
            case .four: ["Vocals", "Drums", "Bass", "Other"]
            case .six: ["Vocals", "Drums", "Bass", "Guitar", "Keys", "Other"]
            case .max: ["Vocals", "Drums", "Bass", "Guitar", "Keys", "Synth", "Other"]
            }
        }
    }
}
