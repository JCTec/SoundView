import Foundation
import Observation

extension StemExportSheet {
    @Observable
    @MainActor
    final class ViewModel {
        let title: String
        let stems: [StemExporter.Stem]
        var selection: StemExportSelection
        var format: StemExportFormat = .wav
        private(set) var progress: Double = 0
        private(set) var isExporting = false
        private(set) var resultURL: URL?
        private(set) var errorMessage: String?
        private var task: Task<Void, Never>?

        init(title: String, stems: [StemExporter.Stem], selection: StemExportSelection) {
            self.title = title
            self.stems = stems
            self.selection = selection
        }

        /// A picked-stem export (from the lane menu) hides the what-to-export choice.
        var showsSelection: Bool {
            if case .pickedStems = selection { return false }
            return true
        }

        var headline: String {
            if case .pickedStems(let ids) = selection, let id = ids.first,
               let stem = stems.first(where: { $0.id == id }) {
                return stem.name
            }
            return title.isEmpty ? "Stems" : title
        }

        func export() {
            guard !isExporting else { return }
            isExporting = true
            errorMessage = nil
            resultURL = nil
            progress = 0
            let exporter = StemExporter(title: title)
            let selection = selection, format = format, stems = stems
            task = Task { [weak self] in
                do {
                    for try await event in exporter.export(stems: stems, selection: selection, format: format) {
                        switch event {
                        case .progress(let value): self?.progress = value
                        case .finished(let url): self?.resultURL = url
                        }
                    }
                } catch is CancellationError {
                    self?.errorMessage = "Cancelled"
                } catch {
                    self?.errorMessage = error.localizedDescription
                }
                self?.isExporting = false
            }
        }

        func cancel() {
            task?.cancel()
            task = nil
            isExporting = false
        }
    }
}
