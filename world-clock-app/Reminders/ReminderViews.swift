import SwiftUI

// MARK: - Reminder List (menu bar popover)

/// Lists, adds, edits, toggles and deletes reminders. Used both in the menu
/// bar popover and in the main window's Reminders sheet.
struct ReminderListView: View {
    @ObservedObject var store: ReminderStore
    var width: CGFloat = 340
    /// Shown as a "Show World Clock" footer button when set (menu bar popover).
    var onShowMainWindow: (() -> Void)?
    /// Shown as a "Done" header button when set (main window sheet).
    var onClose: (() -> Void)?
    @State private var draft: Reminder?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminders")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                if draft == nil {
                    Button { draft = Reminder() } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Add reminder")
                }
                if let onClose {
                    Button("Done", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            }

            if let current = draft {
                ReminderEditorView(
                    reminder: current,
                    isNew: !store.reminders.contains { $0.id == current.id },
                    onSave: { saved in
                        if store.reminders.contains(where: { $0.id == saved.id }) {
                            store.update(saved)
                        } else {
                            store.add(saved)
                        }
                        draft = nil
                    },
                    onCancel: { draft = nil }
                )
            } else if store.reminders.isEmpty {
                Text("No reminders yet. Add one with +, e.g. \"Drink water\" every 45 minutes on weekdays.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        VStack(spacing: 8) {
                            ForEach(store.reminders) { reminder in
                                ReminderRow(
                                    reminder: reminder,
                                    nextFire: store.nextFireDate(for: reminder, now: context.date),
                                    onToggle: { store.setEnabled($0, for: reminder.id) },
                                    onEdit: { draft = reminder },
                                    onDelete: { store.delete(id: reminder.id) }
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 420)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let onShowMainWindow {
                Divider()
                Button(action: onShowMainWindow) {
                    Label("Show World Clock", systemImage: "macwindow")
                        .font(.system(.callout, design: .rounded))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(width: width)
    }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let nextFire: Date?
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(get: { reminder.isEnabled }, set: onToggle))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Text(reminder.scheduleSummary)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                if let nextFire {
                    Text("Next: \(nextFire.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
            .opacity(reminder.isEnabled ? 1 : 0.5)

            Spacer()

            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .help("Edit")
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Delete")
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
    }
}

// MARK: - Reminder Editor

struct ReminderEditorView: View {
    @State private var reminder: Reminder
    let isNew: Bool
    let onSave: (Reminder) -> Void
    let onCancel: () -> Void

    init(reminder: Reminder, isNew: Bool, onSave: @escaping (Reminder) -> Void, onCancel: @escaping () -> Void) {
        _reminder = State(initialValue: reminder)
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title, e.g. Drink water", text: $reminder.title)
                .textFieldStyle(.roundedBorder)

            Stepper(value: $reminder.intervalMinutes, in: 5...480, step: 5) {
                Text("Every \(reminder.intervalMinutes) min")
                    .font(.system(.body, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(Reminder.weekdayDisplayOrder, id: \.self) { day in
                        weekdayChip(day)
                    }
                }
                HStack(spacing: 8) {
                    Button("Weekdays") { reminder.weekdays = Reminder.weekdaysOnly }
                    Button("Every day") { reminder.weekdays = Reminder.everyDay }
                }
                .buttonStyle(.link)
                .font(.system(.caption, design: .rounded))
            }

            HStack {
                DatePicker("From", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("To", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
            }
            .font(.system(.callout, design: .rounded))

            if reminder.startMinute >= reminder.endMinute {
                Text("The end time must be after the start time.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button(isNew ? "Add" : "Save") {
                    reminder.title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(reminder)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!reminder.isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func weekdayChip(_ day: Int) -> some View {
        let isOn = reminder.weekdays.contains(day)
        return Button {
            if isOn { reminder.weekdays.remove(day) } else { reminder.weekdays.insert(day) }
        } label: {
            Text(Reminder.shortWeekdayName(day))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .frame(width: 38, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(isOn ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.1)))
                .foregroundColor(isOn ? .orange : .secondary)
        }
        .buttonStyle(.plain)
    }

    /// Bridges a minute-of-day field to the `Date` a `DatePicker` needs.
    private func minuteBinding(_ keyPath: WritableKeyPath<Reminder, Int>) -> Binding<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Binding(
            get: { calendar.date(byAdding: .minute, value: reminder[keyPath: keyPath], to: today) ?? today },
            set: { newValue in
                let parts = calendar.dateComponents([.hour, .minute], from: newValue)
                reminder[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

// MARK: - Alert Panel (drops down from the menu bar)

/// The alert panel never activates the app, and AppKit draws system buttons in
/// an inactive window as gray. A custom style keeps the colors fixed.
private struct AlertButtonStyle: ButtonStyle {
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isProminent ? .semibold : .medium, design: .rounded))
            .foregroundColor(isProminent ? .black : .white.opacity(0.85))
            .padding(.horizontal, isProminent ? 14 : 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isProminent ? Color.orange : Color.white.opacity(0.1))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

struct ReminderAlertStack: View {
    let alerts: [ReminderAlert]
    let onDone: (UUID) -> Void
    let onSnooze: (UUID, Int) -> Void

    static let snoozeOptions = [5, 10, 15]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(alerts) { alert in
                card(for: alert)
            }
        }
        .padding(8)
        .frame(width: 320)
        .environment(\.colorScheme, .dark)
    }

    private func card(for alert: ReminderAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                    Text(alert.firedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }

            HStack(spacing: 6) {
                Text("Remind in")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                ForEach(ReminderAlertStack.snoozeOptions, id: \.self) { minutes in
                    Button("\(minutes)m") { onSnooze(alert.id, minutes) }
                        .buttonStyle(AlertButtonStyle(isProminent: false))
                }
                Spacer()
                Button("Done") { onDone(alert.id) }
                    .buttonStyle(AlertButtonStyle(isProminent: true))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
        )
    }
}
