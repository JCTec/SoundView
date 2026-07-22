import Foundation
import Observation

extension SeparationView {
    @Observable
    @MainActor
    final class ViewModel {
        let song: SongPackage
        var mode: StemMode
        var quality: SeparationQuality
        private(set) var progress: Double = 0
        private(set) var foundStems: [StemDescriptor] = []
        private(set) var isRunning = false
        private(set) var isFinished = false
        private(set) var errorMessage: String?
        private var task: Task<Void, Never>?

        private var separator: (any StemSeparating)?
        private var catalog: (any ModelCataloging)?

        init(song: SongPackage, mode: StemMode, quality: SeparationQuality = .default) {
            self.song = song
            self.mode = mode
            self.quality = quality
        }

        func isAvailable(_ quality: SeparationQuality) -> Bool {
            guard let catalog else { return true }
            return catalog.isAvailable(quality)
        }

        var isSelectedEngineAvailable: Bool { isAvailable(quality) }

        var progressLabel: String {
            if let errorMessage {
                return errorMessage
            }
            if isFinished {
                return "Done · \(foundStems.count) stems"
            }
            let count = foundStems.count
            let eta = max(1, Int(((1 - progress) * 30).rounded()))
            return "Found \(count) stems so far… · ~\(eta)s left"
        }

        func bind(separator: any StemSeparating, catalog: (any ModelCataloging)?) {
            self.separator = separator
            self.catalog = catalog
        }

        func startSeparation() async {
            guard !isRunning else { return }
            guard isSelectedEngineAvailable else {
                errorMessage = "The studio model isn’t ready in this build yet."
                return
            }
            guard let separator else {
                await startDemoProgress()
                return
            }

            isRunning = true
            isFinished = false
            errorMessage = nil
            foundStems = []
            progress = 0

            do {
                for try await event in separator.separate(
                    packageID: song.id, mode: mode, quality: quality
                ) {
                    switch event {
                    case .progress(let value, _):
                        progress = value
                    case .found(let stem):
                        foundStems.append(stem)
                    case .finished(let stems):
                        foundStems = stems
                        progress = 1
                        isFinished = true
                    }
                }
                isFinished = true
                isRunning = false
            } catch is CancellationError {
                isRunning = false
            } catch {
                errorMessage = humanMessage(for: error)
                isRunning = false
            }
        }

        func cancel() {
            task?.cancel()
            isRunning = false
        }

        private func humanMessage(for error: Error) -> String {
            if let separatorError = error as? StemSeparatorError {
                switch separatorError {
                case .modelUnavailable(let message):
                    return message
                case .missingReferencePack:
                    return "Separation couldn’t finish. Try again."
                }
            }
            return "Separation couldn’t finish. Try again."
        }

        private func startDemoProgress() async {
            isRunning = true
            isFinished = false
            progress = 0
            foundStems = []
            let names = ["Vocals", "Drums", "Bass", "Other"]
            for (index, name) in names.enumerated() {
                try? await Task.sleep(for: .milliseconds(200))
                progress = Double(index + 1) / Double(names.count)
                foundStems.append(
                    StemDescriptor(id: "demo-\(index)", name: name, index: index)
                )
            }
            isFinished = true
            isRunning = false
        }
    }
}
