import Foundation
import Testing
@testable import world_clock_app

@MainActor
struct ReminderScheduleTests {
    private let calendar = TestClock.calendar
    private let water = Reminder(title: "Drink water", intervalMinutes: 45)  // weekdays, 09:00–18:00

    @Test func fireDatesCoverTheWholeWindowIncludingBothEnds() {
        let dates = ReminderSchedule.fireDates(for: water, onDayOf: TestClock.monday(12), calendar: calendar)

        #expect(dates.count == 13)
        #expect(dates.first == TestClock.monday(9))
        #expect(dates[1] == TestClock.monday(9, 45))
        #expect(dates.last == TestClock.monday(18))
    }

    @Test func fireDatesStopBeforeEndWhenIntervalDoesNotDivideTheWindow() {
        let reminder = Reminder(title: "Stretch", intervalMinutes: 50, startMinute: 9 * 60, endMinute: 10 * 60 + 30)
        let dates = ReminderSchedule.fireDates(for: reminder, onDayOf: TestClock.monday(12), calendar: calendar)

        #expect(dates == [TestClock.monday(9), TestClock.monday(9, 50)])
    }

    @Test func noFireDatesOnDaysThatAreNotSelected() {
        let saturday = TestClock.date(2026, 11, 14, 12, 0)

        #expect(ReminderSchedule.fireDates(for: water, onDayOf: saturday, calendar: calendar).isEmpty)
    }

    @Test func nextFireDateIsStrictlyAfterTheGivenTime() {
        #expect(ReminderSchedule.nextFireDate(for: water, after: TestClock.monday(10), calendar: calendar)
            == TestClock.monday(10, 30))
        #expect(ReminderSchedule.nextFireDate(for: water, after: TestClock.monday(10, 30), calendar: calendar)
            == TestClock.monday(11, 15))
    }

    @Test func nextFireDateSkipsTheWeekend() {
        let fridayEvening = TestClock.date(2026, 11, 13, 18, 0)

        #expect(ReminderSchedule.nextFireDate(for: water, after: fridayEvening, calendar: calendar)
            == TestClock.date(2026, 11, 16, 9, 0))
    }

    @Test func lastFireDateLooksBackAcrossDays() {
        #expect(ReminderSchedule.lastFireDate(for: water, onOrBefore: TestClock.monday(10, 40), calendar: calendar)
            == TestClock.monday(10, 30))
        #expect(ReminderSchedule.lastFireDate(for: water, onOrBefore: TestClock.monday(8), calendar: calendar)
            == TestClock.date(2026, 11, 6, 18, 0))
    }

    @Test func invalidRemindersNeverFire() {
        let invalid = [
            Reminder(title: "", intervalMinutes: 45),
            Reminder(title: "No days", weekdays: []),
            Reminder(title: "Backwards", startMinute: 18 * 60, endMinute: 9 * 60),
            Reminder(title: "Zero interval", intervalMinutes: 0),
        ]

        for reminder in invalid {
            #expect(!reminder.isValid)
            #expect(ReminderSchedule.nextFireDate(for: reminder, after: TestClock.monday(8), calendar: calendar) == nil)
        }
    }

    @Test func scheduleSummaryReadsNaturally() {
        #expect(water.scheduleSummary == "Every 45 min · Weekdays · 09:00–18:00")
        #expect(Reminder.weekdaysSummary(Reminder.everyDay) == "Every day")
        #expect(Reminder.weekdaysSummary([1, 7]) == "Weekends")
        #expect(Reminder.weekdaysSummary([4, 2]) == "Mon, Wed")
    }
}
