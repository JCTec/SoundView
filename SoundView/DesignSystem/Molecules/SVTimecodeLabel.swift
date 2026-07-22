import SwiftUI

/// The only way wall-clock audio time is rendered in the UI.
struct SVTimecodeLabel: View {
    let seconds: TimeInterval
    var large: Bool = false
    var showMillis: Bool = false

    var body: some View {
        Text(TimeFormatting.timecode(seconds: seconds, showMillis: showMillis))
            .svTimecode(large: large)
            .accessibilityLabel(TimeFormatting.spokenTimecode(seconds: seconds))
    }
}

#Preview {
    VStack {
        SVTimecodeLabel(seconds: 87.8, large: true, showMillis: true)
        SVTimecodeLabel(seconds: 3723)
    }
    .padding()
    .background(Color.sv.canvas)
}
