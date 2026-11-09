import SwiftUI
import AppKit
import Combine

struct CountdownTimerView: View {
    enum TimerState {
        case idle, running, finished
    }

    @State private var state: TimerState = .idle
    @State private var showingSetup = false
    @State private var totalSeconds = 0
    @State private var remainingSeconds = 0
    @State private var inputMinutes = 5
    @State private var inputSeconds = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var soundPlayCount = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 1 }
        return CGFloat(remainingSeconds) / CGFloat(totalSeconds)
    }

    private var timeDisplay: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        Group {
            switch state {
            case .idle:
                idleView
            case .running:
                runningView
            case .finished:
                finishedView
            }
        }
        .onReceive(ticker) { _ in
            handleTick()
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        Button { showingSetup = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                    .foregroundColor(.white.opacity(0.15))
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 28, weight: .light))
                    Text("Timer")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        .frame(width: 100, height: 100)
        .popover(isPresented: $showingSetup, arrowEdge: .top) {
            setupView
        }
    }

    // MARK: - Setup Popover

    private var setupView: some View {
        VStack(spacing: 20) {
            Text("Set Timer")
                .font(.system(.title3, design: .rounded, weight: .semibold))

            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("\(inputMinutes)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 60)
                    Stepper("", value: $inputMinutes, in: 0...120)
                        .labelsHidden()
                    Text("min")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Text(":")
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
                    .offset(y: -12)

                VStack(spacing: 6) {
                    Text(String(format: "%02d", inputSeconds))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 60)
                    Stepper("", value: $inputSeconds, in: 0...59)
                        .labelsHidden()
                    Text("sec")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                presetButton(label: "1m", minutes: 1, seconds: 0)
                presetButton(label: "5m", minutes: 5, seconds: 0)
                presetButton(label: "10m", minutes: 10, seconds: 0)
                presetButton(label: "25m", minutes: 25, seconds: 0)
            }

            Button {
                startTimer()
                showingSetup = false
            } label: {
                Text("Start")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(inputMinutes == 0 && inputSeconds == 0)
        }
        .padding(24)
        .frame(width: 260)
    }

    private func presetButton(label: String, minutes: Int, seconds: Int) -> some View {
        Button {
            inputMinutes = minutes
            inputSeconds = seconds
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            inputMinutes == minutes && inputSeconds == seconds
                                ? Color.orange.opacity(0.2)
                                : Color.secondary.opacity(0.1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Running

    private var runningView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.07))
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1.5)

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remainingSeconds)

                    Text(timeDisplay)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
                .frame(width: 68, height: 68)

                Button("Cancel") { resetTimer() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .frame(width: 100, height: 100)
    }

    // MARK: - Finished

    private var finishedView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.orange.opacity(0.12))
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1.5)

            VStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.orange)
                    .scaleEffect(pulseScale)

                Text("Time's Up!")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)

                Button("Dismiss") { resetTimer() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.25
            }
        }
    }

    // MARK: - Logic

    private func handleTick() {
        switch state {
        case .running:
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                finishTimer()
            }
        case .finished:
            if soundPlayCount < 10, soundPlayCount % 2 == 0 {
                playAlertSound()
            }
            if soundPlayCount < 10 {
                soundPlayCount += 1
            }
        case .idle:
            break
        }
    }

    private func startTimer() {
        totalSeconds = inputMinutes * 60 + inputSeconds
        remainingSeconds = totalSeconds
        soundPlayCount = 0
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .running
        }
    }

    private func finishTimer() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .finished
        }
        soundPlayCount = 1
        playAlertSound()
        NSApp.requestUserAttention(.criticalRequest)
    }

    private func playAlertSound() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func resetTimer() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .idle
        }
        pulseScale = 1.0
        remainingSeconds = 0
        totalSeconds = 0
        soundPlayCount = 0
    }
}

#Preview {
    HStack(spacing: 12) {
        CountdownTimerView()
    }
    .padding(32)
    .background(Color.black)
}
