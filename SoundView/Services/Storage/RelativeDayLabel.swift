import Foundation

/// Human relative day labels for library rows — pure and testable.
enum RelativeDayLabel {
    static func make(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        // Compare against the injected `now` (not Calendar.isDateInToday, which
        // always uses the wall clock and breaks deterministic tests).
        let startNow = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startDate, to: startNow).day ?? 0

        if days == 0 {
            return "Today"
        }
        if days == 1 {
            return "Yesterday"
        }
        if days > 1, days < 7 {
            return "\(days) days ago"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        }
        return formatter.string(from: date)
    }
}
