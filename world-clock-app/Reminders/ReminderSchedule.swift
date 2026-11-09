import Foundation

/// Pure schedule math for `Reminder`. Fire times on an active day are
/// start, start + interval, start + 2 × interval, ... up to and including end.
enum ReminderSchedule {
    /// How many days to search forward/backward. A week covers every weekday pattern.
    private static let searchDays = 7

    static func fireDates(for reminder: Reminder, onDayOf date: Date, calendar: Calendar) -> [Date] {
        guard reminder.isValid else { return [] }
        let day = calendar.startOfDay(for: date)
        guard reminder.weekdays.contains(calendar.component(.weekday, from: day)) else { return [] }

        return stride(from: reminder.startMinute, through: reminder.endMinute, by: reminder.intervalMinutes)
            .compactMap { calendar.date(byAdding: .minute, value: $0, to: day) }
    }

    /// The first fire time strictly after `date`.
    static func nextFireDate(for reminder: Reminder, after date: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        for offset in 0...searchDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if let match = fireDates(for: reminder, onDayOf: day, calendar: calendar).first(where: { $0 > date }) {
                return match
            }
        }
        return nil
    }

    /// The latest fire time at or before `date`.
    static func lastFireDate(for reminder: Reminder, onOrBefore date: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        for offset in 0...searchDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if let match = fireDates(for: reminder, onDayOf: day, calendar: calendar).last(where: { $0 <= date }) {
                return match
            }
        }
        return nil
    }
}
