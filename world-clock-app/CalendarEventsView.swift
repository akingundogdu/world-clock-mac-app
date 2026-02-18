import SwiftUI
import EventKit
import Combine

// MARK: - Calendar Manager

class CalendarManager: ObservableObject {
    private let store = EKEventStore()
    @Published var events: [EKEvent] = []
    @Published var allCalendars: [EKCalendar] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var authorized = false

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorized = granted
            if granted {
                loadCalendars()
                fetchTodayEvents()
            }
        } catch {
            authorized = false
        }
    }

    func loadCalendars() {
        allCalendars = store.calendars(for: .event)
            .sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
        if selectedCalendarIDs.isEmpty {
            selectedCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
        }
    }

    func fetchTodayEvents() {
        guard !selectedCalendarIDs.isEmpty else {
            events = []
            return
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let selectedCals = allCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selectedCals)
        events = store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
    }

    func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
        } else {
            selectedCalendarIDs.insert(id)
        }
        fetchTodayEvents()
    }

    func selectAll() {
        selectedCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
        fetchTodayEvents()
    }

    func deselectAll() {
        selectedCalendarIDs.removeAll()
        events = []
    }

    var calendarsBySource: [(source: String, calendars: [EKCalendar])] {
        let grouped = Dictionary(grouping: allCalendars) { $0.source.title }
        return grouped.keys.sorted().map { (source: $0, calendars: grouped[$0]!) }
    }
}

// MARK: - Calendar Events View

struct CalendarEventsView: View {
    let containerHeight: CGFloat
    @StateObject private var manager = CalendarManager()
    @State private var now = Date()
    @State private var showingCalendarPicker = false
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var isExpanded: Bool { containerHeight > 110 }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 10 : 8) {
            header

            if !manager.authorized {
                Spacer()
                accessNeeded
                Spacer()
            } else if manager.events.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                eventContent
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
        .task { await manager.requestAccess() }
        .onReceive(timer) { _ in
            now = Date()
            if manager.authorized { manager.fetchTodayEvents() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
            Text("TODAY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
            Text("·")
                .font(.system(size: 10))
            Text(dateString)
                .font(.system(size: 10, weight: .medium, design: .rounded))
            Spacer()

            if manager.authorized {
                if !manager.events.isEmpty {
                    Text("\(manager.events.count) meeting\(manager.events.count == 1 ? "" : "s")")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.25))
                }

                Button {
                    showingCalendarPicker.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingCalendarPicker, arrowEdge: .bottom) {
                    CalendarPickerView(manager: manager)
                }
            }
        }
        .foregroundColor(.white.opacity(0.45))
    }

    // MARK: - States

    private var accessNeeded: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 18))
                Text("Grant calendar access in System Settings")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.2))
            Spacer()
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: manager.selectedCalendarIDs.isEmpty ? "line.3.horizontal.decrease.circle" : "checkmark.circle")
                    .font(.system(size: 13))
                Text(manager.selectedCalendarIDs.isEmpty ? "No calendars selected" : "No meetings today")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.2))
            Spacer()
        }
    }

    // MARK: - Event Content

    @ViewBuilder
    private var eventContent: some View {
        if isExpanded {
            expandedView
                .transition(.opacity)
        } else {
            compactStrip
                .transition(.opacity)
        }
    }

    // MARK: - Compact Strip

    private var compactStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manager.events, id: \.eventIdentifier) { event in
                    EventCardView(event: event, now: now)
                }
            }
        }
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        let s = min(1.4, max(1.0, (containerHeight - 110) / 200.0 + 1.0))

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 5 * s) {
                ForEach(manager.events, id: \.eventIdentifier) { event in
                    ExpandedEventRow(event: event, now: now, scale: s)
                }
            }
        }
    }
}

// MARK: - Compact Event Card

struct EventCardView: View {
    let event: EKEvent
    let now: Date

    private var isActive: Bool {
        !event.isAllDay && now >= event.startDate && now < event.endDate
    }

    private var isPast: Bool {
        if event.isAllDay { return false }
        return now >= event.endDate
    }

    private var timeLabel: String {
        if event.isAllDay { return "All Day" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }

    private var calColor: Color {
        Color(cgColor: event.calendar.cgColor)
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(calColor)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isPast ? .white.opacity(0.3) : .white.opacity(0.85))
                    .lineLimit(1)

                Text(timeLabel)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(isPast ? .white.opacity(0.18) : .white.opacity(0.4))
            }

            if isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 5, height: 5)
                    .shadow(color: .green.opacity(0.6), radius: 3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.white.opacity(0.07) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isActive ? calColor.opacity(0.35) : Color.white.opacity(0.05),
                            lineWidth: 1
                        )
                )
        )
        .opacity(isPast ? 0.55 : 1.0)
    }
}

// MARK: - Expanded Event Row

struct ExpandedEventRow: View {
    let event: EKEvent
    let now: Date
    let scale: CGFloat

    private var isActive: Bool {
        !event.isAllDay && now >= event.startDate && now < event.endDate
    }

    private var isPast: Bool {
        if event.isAllDay { return false }
        return now >= event.endDate
    }

    private var timeLabel: String {
        if event.isAllDay { return "All Day" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }

    private var calColor: Color {
        Color(cgColor: event.calendar.cgColor)
    }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(calColor)
                .frame(width: 3.5, height: 28 * scale)

            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                    .foregroundColor(isPast ? .white.opacity(0.3) : .white.opacity(0.85))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(timeLabel)
                        .font(.system(size: 10 * scale, weight: .medium, design: .monospaced))
                        .foregroundColor(isPast ? .white.opacity(0.18) : .white.opacity(0.4))

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin")
                                .font(.system(size: 7 * scale))
                            Text(location)
                                .font(.system(size: 9 * scale, weight: .regular, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.25))
                        .lineLimit(1)
                    }
                }
            }

            Spacer()

            if isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: .green.opacity(0.6), radius: 3)
                    Text("Now")
                        .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                        .foregroundColor(.green.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7 * scale)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.white.opacity(0.06) : Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isActive ? calColor.opacity(0.3) : Color.white.opacity(0.04),
                            lineWidth: 1
                        )
                )
        )
        .opacity(isPast ? 0.5 : 1.0)
    }
}

// MARK: - Calendar Picker Popover

struct CalendarPickerView: View {
    @ObservedObject var manager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Calendars")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("All") { manager.selectAll() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                Text("·")
                    .foregroundColor(.secondary)
                Button("None") { manager.deselectAll() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(manager.calendarsBySource, id: \.source) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.source)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 16)

                            ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                                CalendarRowView(
                                    calendar: calendar,
                                    isSelected: manager.selectedCalendarIDs.contains(calendar.calendarIdentifier)
                                ) {
                                    manager.toggleCalendar(calendar.calendarIdentifier)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .frame(width: 260, height: 360)
    }
}

struct CalendarRowView: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: () -> Void

    private var calColor: Color {
        Color(cgColor: calendar.cgColor)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? calColor : .secondary.opacity(0.4))

                Circle()
                    .fill(calColor)
                    .frame(width: 8, height: 8)

                Text(calendar.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
