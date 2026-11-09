import Foundation
import Combine

/// A reminder that is due and waiting for the user to dismiss or snooze it.
struct ReminderAlert: Identifiable, Equatable {
    let reminderID: UUID
    var title: String
    var firedAt: Date

    var id: UUID { reminderID }
}

/// Owns the reminder list (persisted in `UserDefaults`), the due alerts and
/// pending snoozes. Time only moves forward through `tick(now:)`, so the
/// logic is deterministic and testable.
final class ReminderStore: ObservableObject {
    static let storageKey = "reminders.v1"

    @Published private(set) var reminders: [Reminder]
    @Published private(set) var activeAlerts: [ReminderAlert] = []
    private(set) var snoozes: [UUID: Date] = [:]

    /// Called once for every alert that becomes visible.
    var onAlertRaised: ((ReminderAlert) -> Void)?

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var lastCheck: Date
    private var ticker: AnyCancellable?

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = Date()) {
        self.defaults = defaults
        self.calendar = calendar
        self.lastCheck = now
        self.reminders = ReminderStore.load(from: defaults)
    }

    // MARK: - Ticking

    func startTicking() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                MainActor.assumeIsolated { self?.tick(now: date) }
            }
    }

    /// Raises alerts for every fire time and expired snooze in `(lastCheck, now]`.
    /// A fire time older than one interval is skipped, so waking the Mac from a
    /// long sleep does not show stale reminders.
    func tick(now: Date) {
        guard now > lastCheck else { return }
        defer { lastCheck = now }

        for reminder in reminders where reminder.isEnabled {
            guard let fired = ReminderSchedule.lastFireDate(for: reminder, onOrBefore: now, calendar: calendar),
                  fired > lastCheck,
                  now.timeIntervalSince(fired) < TimeInterval(reminder.intervalMinutes * 60)
            else { continue }
            raise(reminder, firedAt: fired)
        }

        for (id, until) in snoozes where until <= now {
            snoozes[id] = nil
            if let reminder = reminders.first(where: { $0.id == id }) {
                raise(reminder, firedAt: until)
            }
        }
    }

    func nextFireDate(for reminder: Reminder, now: Date = Date()) -> Date? {
        guard reminder.isEnabled else { return nil }
        let scheduled = ReminderSchedule.nextFireDate(for: reminder, after: now, calendar: calendar)
        guard let snoozed = snoozes[reminder.id] else { return scheduled }
        return min(snoozed, scheduled ?? snoozed)
    }

    // MARK: - Alerts

    func dismiss(alertID: UUID) {
        activeAlerts.removeAll { $0.id == alertID }
    }

    func snooze(alertID: UUID, minutes: Int, now: Date = Date()) {
        dismiss(alertID: alertID)
        snoozes[alertID] = now.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func raise(_ reminder: Reminder, firedAt: Date) {
        snoozes[reminder.id] = nil
        if let index = activeAlerts.firstIndex(where: { $0.reminderID == reminder.id }) {
            activeAlerts[index].firedAt = firedAt
            activeAlerts[index].title = reminder.title
            return
        }
        let alert = ReminderAlert(reminderID: reminder.id, title: reminder.title, firedAt: firedAt)
        activeAlerts.append(alert)
        onAlertRaised?(alert)
    }

    // MARK: - Editing

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
        save()
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        if !reminder.isEnabled { snoozes[reminder.id] = nil }
        save()
    }

    func setEnabled(_ isEnabled: Bool, for id: UUID) {
        guard var reminder = reminders.first(where: { $0.id == id }) else { return }
        reminder.isEnabled = isEnabled
        update(reminder)
    }

    func delete(id: UUID) {
        reminders.removeAll { $0.id == id }
        activeAlerts.removeAll { $0.reminderID == id }
        snoozes[id] = nil
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        defaults.set(data, forKey: ReminderStore.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [Reminder] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data)
        else { return [] }
        return decoded
    }
}
