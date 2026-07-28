import SwiftUI

extension Notification.Name {
    static let openStatistics = Notification.Name("pomodoro.openStatistics")
}

struct PopoverView: View {
    @EnvironmentObject var engine: TimerEngine
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            header
            if showSettings {
                SettingsView()
            } else {
                TimerPane()
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("🍅 Pomodoro")
                .font(.headline)
            Spacer()
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: showSettings ? "timer" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help(showSettings ? "Back to timer" : "Settings")
        }
    }

    private var footer: some View {
        HStack {
            Button("Statistics…") {
                NotificationCenter.default.post(name: .openStatistics, object: nil)
            }
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}

struct TimerPane: View {
    @EnvironmentObject var engine: TimerEngine

    private static let endTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 10) {
            positionLine
            switch engine.phase {
            case .idle:
                idleView
            case .running(let kind):
                runningView(kind)
            case .ringing(let kind):
                ringingView(kind)
            }
            todayLine
        }
    }

    private var positionLine: some View {
        Text("Loop \(min(engine.currentLoop, engine.config.loopsPerSprint)) of \(engine.config.loopsPerSprint)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Text("Up next: \(engine.nextKind.label) · \(engine.config.minutes(for: engine.nextKind)) min")
                .font(.title3)
            Button {
                engine.startNextSegment()
            } label: {
                Text("Start \(engine.nextKind.label)")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            Button("Reset sprint") { engine.resetSprint() }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func runningView(_ kind: SegmentKind) -> some View {
        VStack(spacing: 6) {
            Text(kind.label)
                .font(.title3)
                .foregroundStyle(kind.isBreak ? .green : .red)
            Text(String(format: "%d:%02d", engine.remainingSeconds / 60, engine.remainingSeconds % 60))
                .font(.system(size: 44, weight: .medium, design: .rounded))
                .monospacedDigit()
            if let end = engine.segmentEnd {
                Text("ends at \(Self.endTimeFormatter.string(from: end))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Cancel segment") { engine.cancelSegment() }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func ringingView(_ kind: SegmentKind) -> some View {
        VStack(spacing: 8) {
            Text("🔔 \(kind.label) finished!")
                .font(.title3)
            Button {
                engine.acknowledge()
            } label: {
                Text("Stop bell")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var todayLine: some View {
        let summary = engine.store.summary(
            in: Calendar.current.dateInterval(of: .day, for: engine.now)
                ?? DateInterval(start: engine.now, duration: 0))
        return Text("Today: \(summary.workSessions) work · \(summary.loops) loops · \(summary.sprints) sprints")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct SettingsView: View {
    @EnvironmentObject var engine: TimerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingRow("Work", minutes: $engine.config.workMinutes, suffix: "min")
            settingRow("Break", minutes: $engine.config.shortBreakMinutes, suffix: "min")
            settingRow("Loops per sprint", minutes: $engine.config.loopsPerSprint, suffix: "×")
            settingRow("Long break", minutes: $engine.config.longBreakMinutes, suffix: "min")
            HStack {
                Spacer()
                Button("Restore defaults") { engine.config = Config() }
                    .font(.caption)
            }
            Text("Changes apply from the next segment.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func settingRow(_ label: String, minutes: Binding<Int>, suffix: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: minutes, in: 1...180) {
                Text("\(minutes.wrappedValue) \(suffix)")
                    .monospacedDigit()
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }
}
