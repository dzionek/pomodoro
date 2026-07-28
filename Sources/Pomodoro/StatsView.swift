import SwiftUI

struct StatsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: HistoryStore
    @State private var mode: Mode = .day
    @State private var referenceDate = Date()

    private var calendar: Calendar { Calendar.current }

    private var interval: DateInterval {
        let component: Calendar.Component = mode == .day ? .day : .weekOfYear
        return calendar.dateInterval(of: component, for: referenceDate)
            ?? DateInterval(start: referenceDate, duration: 86400)
    }

    private var days: [Date] {
        var result: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(12)
            Divider()
            TimelineGrid(days: days, sessions: store.sessions(in: interval))
            Divider()
            legend
                .padding(10)
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Spacer()
                HStack(spacing: 4) {
                    Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    Button("Today") { referenceDate = Date() }
                    Button { step(1) } label: { Image(systemName: "chevron.right") }
                }
            }
            HStack {
                Text(rangeTitle)
                    .font(.headline)
                Spacer()
                summaryText
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rangeTitle: String {
        let formatter = DateFormatter()
        if mode == .day {
            formatter.dateStyle = .full
            return formatter.string(from: interval.start)
        }
        formatter.dateFormat = "d MMM"
        let endDay = interval.end.addingTimeInterval(-1)
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: endDay)), \(calendar.component(.year, from: interval.start))"
    }

    private var summaryText: Text {
        let summary = store.summary(in: interval)
        return Text(
            "\(summary.workSessions) work sessions · \(summary.loops) loops · \(summary.sprints) sprints · " +
            "\(summary.workMinutes) min work · \(summary.breakMinutes) min break")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .red, label: "Work")
            legendItem(color: .green, label: "Break")
            Spacer()
            Text("Hatched = segment cancelled early")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.7))
                .frame(width: 14, height: 10)
            Text(label).font(.caption)
        }
    }

    private func step(_ direction: Int) {
        let component: Calendar.Component = mode == .day ? .day : .weekOfYear
        if let next = calendar.date(byAdding: component, value: direction, to: referenceDate) {
            referenceDate = next
        }
    }
}

/// Hour-by-hour grid: one column per day, sessions drawn as colored blocks
/// at their exact minutes. Gaps stay blank.
struct TimelineGrid: View {
    let days: [Date]
    let sessions: [Session]

    private let hourHeight: CGFloat = 44
    private let labelWidth: CGFloat = 48

    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if days.count > 1 {
                dayHeaders
                Divider()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        hourLabels
                        ForEach(days, id: \.self) { day in
                            DayColumn(day: day, sessions: sessions, hourHeight: hourHeight)
                                .overlay(alignment: .leading) { Divider() }
                        }
                    }
                    .id("grid")
                    // Anchor markers so we can scroll to the working hours.
                    .background(alignment: .top) {
                        Color.clear.frame(height: 1).offset(y: 8 * hourHeight).id("morning")
                    }
                }
                .onAppear { proxy.scrollTo("morning", anchor: .top) }
            }
        }
    }

    private var dayHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth, height: 24)
            ForEach(days, id: \.self) { day in
                Text(Self.dayHeaderFormatter.string(from: day))
                    .font(.caption.weight(Calendar.current.isDateInToday(day) ? .bold : .regular))
                    .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.red : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
        }
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 4)
            }
        }
    }
}

struct DayColumn: View {
    let day: Date
    let sessions: [Session]
    let hourHeight: CGFloat

    private static let blockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var dayInterval: DateInterval {
        Calendar.current.dateInterval(of: .day, for: day)
            ?? DateInterval(start: day, duration: 86400)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour lines
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: hourHeight)
                        .overlay(alignment: .top) {
                            Divider().opacity(0.5)
                        }
                }
            }
            // Session blocks
            GeometryReader { geo in
                ForEach(visibleSessions) { session in
                    block(for: session, width: geo.size.width)
                }
            }
        }
        .frame(height: 24 * hourHeight)
        .frame(maxWidth: .infinity)
    }

    private var visibleSessions: [Session] {
        sessions.filter { $0.end > dayInterval.start && $0.start < dayInterval.end }
    }

    private func block(for session: Session, width: CGFloat) -> some View {
        let start = max(session.start, dayInterval.start)
        let end = min(session.end, dayInterval.end)
        let yOffset = start.timeIntervalSince(dayInterval.start) / 3600 * hourHeight
        let height = max(2, end.timeIntervalSince(start) / 3600 * hourHeight)
        let color: Color = session.kind == .work ? .red : .green

        return RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(session.completed ? 0.7 : 0.35))
            .overlay {
                if !session.completed {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [3]))
                }
            }
            .frame(width: max(4, width - 8), height: height)
            .offset(x: 4, y: yOffset)
            .help("\(session.kind.label): \(Self.blockFormatter.string(from: session.start)) – \(Self.blockFormatter.string(from: session.end)) (\(session.durationMinutes) min)\(session.completed ? "" : " — cancelled")")
    }
}
