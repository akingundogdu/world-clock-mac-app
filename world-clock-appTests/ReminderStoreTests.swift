import Foundation
import Testing
@testable import world_clock_app

@MainActor
struct ReminderStoreTests {
    private let water = Reminder(title: "Drink water", intervalMinutes: 45)  // weekdays, 09:00–18:00

    private func makeStore(now: Date, defaults: UserDefaults = TestClock.freshDefaults()) -> ReminderStore {
        ReminderStore(defaults: defaults, calendar: TestClock.calendar, now: now)
    }

    @Test func raisesAnAlertOnlyOnceTheFireTimeIsReached() {
        let store = makeStore(now: TestClock.monday(9, 1))
        store.add(water)

        store.tick(now: TestClock.monday(9, 44))
        #expect(store.activeAlerts.isEmpty)

        store.tick(now: TestClock.monday(9, 45))
        #expect(store.activeAlerts.map(\.reminderID) == [water.id])
        #expect(store.activeAlerts.first?.firedAt == TestClock.monday(9, 45))
    }

    @Test func doesNotFireForTimesBeforeTheStoreStarted() {
        let store = makeStore(now: TestClock.monday(9, 0, 30))
        store.add(water)

        store.tick(now: TestClock.monday(9, 1))
        #expect(store.activeAlerts.isEmpty)
    }

    @Test func keepsOneAlertPerReminderAndNotifiesOnce() {
        let store = makeStore(now: TestClock.monday(9, 1))
        store.add(water)
        var raisedCount = 0
        store.onAlertRaised = { _ in raisedCount += 1 }

        store.tick(now: TestClock.monday(9, 45))
        store.tick(now: TestClock.monday(10, 30))

        #expect(store.activeAlerts.count == 1)
        #expect(store.activeAlerts.first?.firedAt == TestClock.monday(10, 30))
        #expect(raisedCount == 1)
    }

    @Test func skipsStaleFireTimesAfterALongSleep() {
        let store = makeStore(now: TestClock.monday(8))
        store.add(water)

        // Last fire time is 18:00; an hour later is older than the 45 min interval.
        store.tick(now: TestClock.monday(19))
        #expect(store.activeAlerts.isEmpty)
    }

    @Test func showsTheMostRecentMissedFireAfterAShortSleep() {
        let store = makeStore(now: TestClock.monday(8))
        store.add(water)

        store.tick(now: TestClock.monday(12, 10))
        #expect(store.activeAlerts.first?.firedAt == TestClock.monday(12))
    }

    @Test func disabledRemindersDoNotFire() {
        let store = makeStore(now: TestClock.monday(9, 1))
        store.add(water)
        store.setEnabled(false, for: water.id)

        store.tick(now: TestClock.monday(9, 45))
        #expect(store.activeAlerts.isEmpty)
        #expect(store.nextFireDate(for: store.reminders[0], now: TestClock.monday(9, 1)) == nil)
    }

    @Test func dismissClosesTheAlert() {
        let store = makeStore(now: TestClock.monday(9, 1))
        store.add(water)
        store.tick(now: TestClock.monday(9, 45))

        store.dismiss(alertID: water.id)
        #expect(store.activeAlerts.isEmpty)
    }

    @Test func snoozeClosesTheAlertAndRaisesItAgainLater() {
        let store = makeStore(now: TestClock.monday(9, 1))
        store.add(water)
        store.tick(now: TestClock.monday(9, 45))

        store.snooze(alertID: water.id, minutes: 10, now: TestClock.monday(9, 46))
        #expect(store.activeAlerts.isEmpty)
        #expect(store.nextFireDate(for: water, now: TestClock.monday(9, 47)) == TestClock.monday(9, 56))

        store.tick(now: TestClock.monday(9, 55))
        #expect(store.activeAlerts.isEmpty)

        store.tick(now: TestClock.monday(9, 56))
        #expect(store.activeAlerts.first?.firedAt == TestClock.monday(9, 56))
        #expect(store.snoozes.isEmpty)
    }

    @Test func deleteRemovesTheReminderItsAlertAndItsSnooze() {
        let store = makeStore(now: TestClock.monday(9, 1))
        let stretch = Reminder(title: "Stretch", intervalMinutes: 30)
        store.add(water)
        store.add(stretch)
        store.tick(now: TestClock.monday(9, 45))
        store.snooze(alertID: stretch.id, minutes: 5, now: TestClock.monday(9, 46))

        store.delete(id: water.id)
        store.delete(id: stretch.id)

        #expect(store.reminders.isEmpty)
        #expect(store.activeAlerts.isEmpty)
        #expect(store.snoozes.isEmpty)
    }

    @Test func remindersPersistAcrossLaunches() {
        let defaults = TestClock.freshDefaults()
        let first = makeStore(now: TestClock.monday(9), defaults: defaults)
        first.add(water)
        var edited = water
        edited.intervalMinutes = 30
        first.update(edited)

        let relaunched = makeStore(now: TestClock.monday(9), defaults: defaults)
        #expect(relaunched.reminders == [edited])
    }
}

private extension TestClock {
    static func monday(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        monday(hour, minute).addingTimeInterval(TimeInterval(second))
    }
}
