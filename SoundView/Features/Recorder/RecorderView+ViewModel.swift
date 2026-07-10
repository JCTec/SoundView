import Foundation
import Observation

extension RecorderView {
    @Observable
    @MainActor
    final class ViewModel {
        private(set) var isRecording = false
        private(set) var elapsed: TimeInterval = 0
        private var timer: Timer?

        var statusTitle: String {
            if isRecording { return "RECORDING" }
            if elapsed > 0 { return "PAUSED" }
            return "Tap to record"
        }

        var technicalStrip: String {
            "48 kHz · WAV · peak ready"
        }

        func toggleRecord() {
            if isRecording {
                isRecording = false
                timer?.invalidate()
            } else {
                isRecording = true
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        self?.elapsed += 0.1
                    }
                }
            }
        }

        func stopAndSave() {
            isRecording = false
            timer?.invalidate()
            // FileStore + auto-separate next.
        }
    }
}
