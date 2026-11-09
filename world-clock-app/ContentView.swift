import SwiftUI
import AppKit
import Combine

struct ClockItem: Identifiable, Equatable {
    let id: UUID
    var city: String
    var timeZoneID: String
    var sizeMultiplier: CGFloat
    var isDark: Bool

    init(id: UUID = UUID(), city: String, timeZoneID: String, sizeMultiplier: CGFloat = 1.0, isDark: Bool = true) {
        self.id = id
        self.city = city
        self.timeZoneID = timeZoneID
        self.sizeMultiplier = sizeMultiplier
        self.isDark = isDark
    }
}

struct ContentView: View {
    @State private var clocks: [ClockItem] = [
        ClockItem(city: "IST", timeZoneID: "Europe/Istanbul"),
        ClockItem(city: "NYC", timeZoneID: "America/New_York"),
        ClockItem(city: "SF", timeZoneID: "America/Los_Angeles")
    ]
    @EnvironmentObject private var reminderStore: ReminderStore
    @State private var showingAddSheet = false
    @State private var showingReminders = false
    @State private var calendarHeight: CGFloat = 80
    @State private var dragStartHeight: CGFloat? = nil
    @State private var currentDate = Date()
    private let dateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        return formatter.string(from: currentDate)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(formattedDate)
                    .font(.system(size: 64, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    // Shrink instead of truncating when the window is narrow.
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                GeometryReader { geo in
                    let baseSize = computeBaseSize(in: geo.size)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: 20) {
                            ForEach($clocks) { $clock in
                                ClockWidgetView(clock: $clock, baseSize: baseSize) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        clocks.removeAll { $0.id == clock.id }
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 32)
                        .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                    }
                }

                // The action tiles get their own row so they never cover a clock.
                HStack(spacing: 12) {
                    Spacer()
                    RemindersButton(activeCount: reminderStore.reminders.filter(\.isEnabled).count) {
                        showingReminders = true
                    }
                    CountdownTimerView()
                    AddClockButton {
                        showingAddSheet = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                calendarDragHandle

                CalendarEventsView(containerHeight: calendarHeight)
                    .frame(height: calendarHeight)
                    .clipped()
            }
        }
        .onReceive(dateTimer) { currentDate = $0 }
        .sheet(isPresented: $showingAddSheet) {
            AddClockSheet { newClock in
                withAnimation(.easeInOut(duration: 0.3)) {
                    clocks.append(newClock)
                }
            }
        }
        .sheet(isPresented: $showingReminders) {
            ReminderListView(store: reminderStore, width: 440, onClose: { showingReminders = false })
                .frame(minHeight: 320, alignment: .top)
        }
    }

    // MARK: - Calendar Drag Handle

    private var calendarDragHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
        }
        .frame(height: 14)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStartHeight == nil { dragStartHeight = calendarHeight }
                    withAnimation(.interactiveSpring) {
                        calendarHeight = max(60, min(300, (dragStartHeight ?? 80) - value.translation.height))
                    }
                }
                .onEnded { _ in
                    dragStartHeight = nil
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func computeBaseSize(in viewSize: CGSize) -> CGFloat {
        let count = CGFloat(max(clocks.count, 1))
        let totalSpacing = 20.0 * (count - 1) + 32.0 * 2
        let fitWidth = (viewSize.width - totalSpacing) / count
        let fitHeight = viewSize.height * 0.88
        return min(fitWidth, fitHeight)
    }
}

// MARK: - Add Clock Button

struct AddClockButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                .foregroundColor(.white.opacity(0.15))
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .light))
                        Text("Add Clock")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.3))
                }
        }
        .buttonStyle(.plain)
        .frame(width: 100, height: 100)
    }
}

// MARK: - Reminders Button

struct RemindersButton: View {
    var activeCount: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                .foregroundColor(.white.opacity(0.15))
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "bell")
                            .font(.system(size: 28, weight: .light))
                        Text(activeCount > 0 ? "Reminders (\(activeCount))" : "Reminders")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.3))
                }
        }
        .buttonStyle(.plain)
        .frame(width: 100, height: 100)
    }
}

// MARK: - Add Clock Sheet

struct CityPreset: Identifiable {
    let id = UUID()
    let abbreviation: String
    let fullName: String
    let timeZoneID: String
}

private let cityPresets: [CityPreset] = [
    CityPreset(abbreviation: "IST", fullName: "Istanbul", timeZoneID: "Europe/Istanbul"),
    CityPreset(abbreviation: "NYC", fullName: "New York", timeZoneID: "America/New_York"),
    CityPreset(abbreviation: "SF", fullName: "San Francisco", timeZoneID: "America/Los_Angeles"),
    CityPreset(abbreviation: "LON", fullName: "London", timeZoneID: "Europe/London"),
    CityPreset(abbreviation: "PAR", fullName: "Paris", timeZoneID: "Europe/Paris"),
    CityPreset(abbreviation: "BER", fullName: "Berlin", timeZoneID: "Europe/Berlin"),
    CityPreset(abbreviation: "MOS", fullName: "Moscow", timeZoneID: "Europe/Moscow"),
    CityPreset(abbreviation: "DXB", fullName: "Dubai", timeZoneID: "Asia/Dubai"),
    CityPreset(abbreviation: "MUM", fullName: "Mumbai", timeZoneID: "Asia/Kolkata"),
    CityPreset(abbreviation: "BKK", fullName: "Bangkok", timeZoneID: "Asia/Bangkok"),
    CityPreset(abbreviation: "HKG", fullName: "Hong Kong", timeZoneID: "Asia/Hong_Kong"),
    CityPreset(abbreviation: "SGP", fullName: "Singapore", timeZoneID: "Asia/Singapore"),
    CityPreset(abbreviation: "TKY", fullName: "Tokyo", timeZoneID: "Asia/Tokyo"),
    CityPreset(abbreviation: "SEL", fullName: "Seoul", timeZoneID: "Asia/Seoul"),
    CityPreset(abbreviation: "SYD", fullName: "Sydney", timeZoneID: "Australia/Sydney"),
    CityPreset(abbreviation: "AKL", fullName: "Auckland", timeZoneID: "Pacific/Auckland"),
    CityPreset(abbreviation: "CHI", fullName: "Chicago", timeZoneID: "America/Chicago"),
    CityPreset(abbreviation: "DEN", fullName: "Denver", timeZoneID: "America/Denver"),
    CityPreset(abbreviation: "HON", fullName: "Honolulu", timeZoneID: "Pacific/Honolulu"),
    CityPreset(abbreviation: "SAO", fullName: "São Paulo", timeZoneID: "America/Sao_Paulo"),
    CityPreset(abbreviation: "MEX", fullName: "Mexico City", timeZoneID: "America/Mexico_City"),
    CityPreset(abbreviation: "JKT", fullName: "Jakarta", timeZoneID: "Asia/Jakarta"),
]

struct AddClockSheet: View {
    @Environment(\.dismiss) var dismiss
    var onAdd: (ClockItem) -> Void
    @State private var searchText = ""
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var filtered: [CityPreset] {
        if searchText.isEmpty { return cityPresets }
        return cityPresets.filter {
            $0.abbreviation.localizedCaseInsensitiveContains(searchText) ||
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Clock")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()

            TextField("Search cities...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filtered) { city in
                Button {
                    onAdd(ClockItem(city: city.abbreviation, timeZoneID: city.timeZoneID))
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.abbreviation)
                                .font(.system(.headline, design: .rounded))
                            Text(city.fullName)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formattedTime(for: city.timeZoneID))
                            .font(.system(.body, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 360, height: 480)
        .onReceive(timer) { currentTime = $0 }
    }

    private func formattedTime(for tzID: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: tzID)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
}

#Preview {
    ContentView()
        .environmentObject(ReminderStore())
        .frame(width: 900, height: 580)
}
