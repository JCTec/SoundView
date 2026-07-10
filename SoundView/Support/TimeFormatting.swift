import Foundation

/// Pure timecode formatting — no `DateFormatter` in hot paths.
enum TimeFormatting {
    static func timecode(seconds: TimeInterval, showMillis: Bool = false) -> String {
        let total = max(0, seconds)
        let hours = Int(total) / 3_600
        let minutes = (Int(total) % 3_600) / 60
        let secs = Int(total) % 60
        let millis = Int((total.truncatingRemainder(dividingBy: 1)) * 10)

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        if showMillis {
            return String(format: "%d:%02d.%d", minutes, secs, millis)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func spokenTimecode(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours) hours, \(minutes) minutes, \(secs) seconds"
        }
        if minutes > 0 {
            return "\(minutes) minutes, \(secs) seconds"
        }
        return "\(secs) seconds"
    }
}
