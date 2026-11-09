import Foundation

/// A recurring reminder that fires every `intervalMinutes` between `startMinute`
/// and `endMinute` (both inclusive, minutes after midnight) on the selected weekdays.
struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var intervalMinutes: Int
    /// Calendar weekday numbers: 1 = Sunday, 2 = Monday, ... 7 = Saturday.
    var weekdays: Set<Int>
    var startMinute: Int
    var endMinute: Int
    var isEnabled: Bool

    static let weekdaysOnly: Set<Int> = [2, 3, 4, 5, 6]
    static let everyDay: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    /// Display order of weekdays, starting on Monday.
    static let weekdayDisplayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

    init(
        id: UUID = UUID(),
        title: String = "",
        intervalMinutes: Int = 45,
        weekdays: Set<Int> = Reminder.weekdaysOnly,
        startMinute: Int = 9 * 60,
        endMinute: Int = 18 * 60,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.intervalMinutes = intervalMinutes
        self.weekdays = weekdays
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.isEnabled = isEnabled
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && intervalMinutes > 0
            && !weekdays.isEmpty
            && weekdays.isSubset(of: Reminder.everyDay)
            && startMinute >= 0
            && endMinute <= 24 * 60
            && startMinute < endMinute
    }

    /// Human readable schedule, e.g. "Every 45 min · Weekdays · 09:00–18:00".
    var scheduleSummary: String {
        "Every \(intervalMinutes) min · \(Reminder.weekdaysSummary(weekdays)) · "
            + "\(Reminder.timeString(startMinute))–\(Reminder.timeString(endMinute))"
    }

    static func weekdaysSummary(_ days: Set<Int>) -> String {
        switch days {
        case everyDay: return "Every day"
        case weekdaysOnly: return "Weekdays"
        case [1, 7]: return "Weekends"
        default:
            return weekdayDisplayOrder
                .filter { days.contains($0) }
                .map { shortWeekdayName($0) }
                .joined(separator: ", ")
        }
    }

    static func shortWeekdayName(_ weekday: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard (1...7).contains(weekday) else { return "?" }
        return names[weekday - 1]
    }

    static func timeString(_ minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}
