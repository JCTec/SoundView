import SwiftUI

/// Record pipeline entry — sheet (phone) / slide-over (iPad desk).
struct RecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: SVSpacing.xl) {
                Text(viewModel.statusTitle)
                    .svCaption()

                SVTimecodeLabel(seconds: viewModel.elapsed, large: true, showMillis: true)

                Text(viewModel.technicalStrip)
                    .svCaption()

                Spacer()

                Button {
                    viewModel.toggleRecord()
                } label: {
                    Circle()
                        .fill(viewModel.isRecording ? Color.sv.record : Color.sv.surface)
                        .frame(width: 88, height: 88)
                        .overlay {
                            Image(systemName: viewModel.isRecording ? "pause.fill" : "mic.fill")
                                .font(.title)
                                .foregroundStyle(Color.sv.textPrimary)
                        }
                }
                .accessibilityIdentifier(A11yID.Recorder.recordToggle)
                .accessibilityLabel(viewModel.isRecording ? "Pause" : "Record")

                HStack(spacing: SVSpacing.md) {
                    SVCapsuleButton(
                        title: "Discard",
                        style: .secondary,
                        action: { dismiss() }
                    )
                    SVCapsuleButton(
                        title: "Stop & Save",
                        style: .primary,
                        isEnabled: viewModel.elapsed > 0,
                        action: {
                            viewModel.stopAndSave()
                            dismiss()
                        }
                    )
                    .accessibilityIdentifier(A11yID.Recorder.stop)
                }
                .padding()
            }
            .padding(.top, SVSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.sv.canvas)
            .navigationTitle("Recorder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .accessibilityIdentifier(A11yID.Recorder.screen)
        }
    }
}

#Preview {
    RecorderView()
}
