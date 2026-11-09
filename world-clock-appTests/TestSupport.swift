import Foundation

/// Fixed calendar so the tests do not depend on the machine's time zone.
/// Europe/Istanbul has no daylight saving time. 2026-11-09 is a Monday.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Monday 2026-11-09 at the given time.
    static func monday(_ hour: Int, _ minute: Int = 0) -> Date { date(2026, 11, 9, hour, minute) }

    /// A fresh, empty `UserDefaults` suite per test.
    static func freshDefaults() -> UserDefaults {
        let name = "world-clock-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
