import SwiftUI
import Combine

struct ClockWidgetView: View {
    @Binding var clock: ClockItem
    var baseSize: CGFloat
    var onDelete: () -> Void

    @State private var currentTime = Date()
    @State private var isHovering = false
    @GestureState private var magnification: CGFloat = 1.0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var displaySize: CGFloat {
        let raw = baseSize * clock.sizeMultiplier * magnification
        return max(80, raw)
    }

    private var cornerRadius: CGFloat {
        displaySize * 0.16
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: clock.timeZoneID)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private var offsetHours: Int {
        guard let tz = TimeZone(identifier: clock.timeZoneID) else { return 0 }
        let diff = tz.secondsFromGMT(for: currentTime) - TimeZone.current.secondsFromGMT(for: currentTime)
        return diff / 3600
    }

    var body: some View {
        ZStack {
            background
            tickMarks
            clockContent

            if isHovering {
                hoverControls
            }
        }
        .frame(width: displaySize, height: displaySize)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .highPriorityGesture(magnifyGesture)
        .onReceive(timer) { currentTime = $0 }
        .contextMenu {
            Button(clock.isDark ? "Light Theme" : "Dark Theme") {
                withAnimation(.easeInOut(duration: 0.25)) { clock.isDark.toggle() }
            }
            Button("Reset Size") {
                withAnimation(.spring(duration: 0.3)) { clock.sizeMultiplier = 1.0 }
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(clock.city), \(timeString)")
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(clock.isDark ? Color(white: 0.07) : Color.white)

            if clock.isDark {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Tick Marks

    private var tickMarks: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.43

            for i in 0..<60 {
                let angle = Angle.degrees(Double(i) * 6 - 90)
                let isLong = i % 5 == 0
                let tickLength = isLong ? size.width * 0.05 : size.width * 0.025
                let tickWidth: CGFloat = isLong ? 1.6 : 0.7

                let cos = cos(angle.radians)
                let sin = sin(angle.radians)

                let outer = CGPoint(
                    x: center.x + radius * cos,
                    y: center.y + radius * sin
                )
                let inner = CGPoint(
                    x: center.x + (radius - tickLength) * cos,
                    y: center.y + (radius - tickLength) * sin
                )

                var path = Path()
                path.move(to: outer)
                path.addLine(to: inner)

                let color: Color = clock.isDark
                    ? Color(white: 0.3)
                    : Color(white: 0.72)

                context.stroke(path, with: .color(color), lineWidth: tickWidth)
            }
        }
    }

    // MARK: - Clock Content

    private var clockContent: some View {
        VStack(spacing: displaySize * 0.015) {
            Text(clock.city)
                .font(.system(size: displaySize * 0.085, weight: .semibold, design: .rounded))
                .foregroundColor(clock.isDark ? Color(white: 0.5) : Color(white: 0.45))
                .tracking(2)

            Text(timeString)
                .font(.system(size: displaySize * 0.27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(clock.isDark ? .white : .black)

            if offsetHours != 0 {
                Text(offsetHours > 0 ? "+\(offsetHours)" : "\(offsetHours)")
                    .font(.system(size: displaySize * 0.07, weight: .medium, design: .rounded))
                    .foregroundColor(clock.isDark ? Color(white: 0.4) : Color(white: 0.55))
            } else {
                Color.clear.frame(height: displaySize * 0.07)
            }
        }
    }

    // MARK: - Hover Controls

    private var hoverControls: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.black.opacity(0.15))

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                Spacer()
            }

            VStack {
                Spacer()
                HStack(spacing: 16) {
                    resizeButton(systemName: "minus.circle.fill", delta: -0.15)
                    resizeButton(systemName: "plus.circle.fill", delta: 0.15)
                }
                .padding(.bottom, 10)
            }
        }
        .transition(.opacity)
    }

    private func resizeButton(systemName: String, delta: CGFloat) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                clock.sizeMultiplier = max(0.4, min(2.5, clock.sizeMultiplier + delta))
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 24))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white.opacity(0.9), .white.opacity(0.2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                clock.sizeMultiplier = max(0.4, min(2.5, clock.sizeMultiplier * value.magnification))
            }
    }
}

#Preview {
    HStack(spacing: 20) {
        ClockWidgetView(
            clock: .constant(ClockItem(city: "IST", timeZoneID: "Europe/Istanbul")),
            baseSize: 280,
            onDelete: {}
        )
        ClockWidgetView(
            clock: .constant(ClockItem(city: "NYC", timeZoneID: "America/New_York")),
            baseSize: 280,
            onDelete: {}
        )
        ClockWidgetView(
            clock: .constant(ClockItem(city: "SF", timeZoneID: "America/Los_Angeles")),
            baseSize: 280,
            onDelete: {}
        )
    }
    .padding(32)
    .background(Color.black)
}
