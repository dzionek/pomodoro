import Foundation

/// Persists the session history as JSON in Application Support and
/// answers queries about what happened in a given time interval.
final class HistoryStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    private let fileURL: URL

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("sessions.json")
        load()
    }

    func add(_ session: Session) {
        sessions.append(session)
        save()
    }

    /// Sessions overlapping the interval (a session may cross its edges).
    func sessions(in interval: DateInterval) -> [Session] {
        sessions.filter { $0.end > interval.start && $0.start < interval.end }
    }

    struct Summary {
        var workSessions = 0   // completed work segments
        var loops = 0          // completed breaks (each closes a work+break loop)
        var sprints = 0        // completed long breaks (each closes a sprint)
        var workMinutes = 0
        var breakMinutes = 0
    }

    func summary(in interval: DateInterval) -> Summary {
        var result = Summary()
        for session in sessions(in: interval) {
            let clippedStart = max(session.start, interval.start)
            let clippedEnd = min(session.end, interval.end)
            let minutes = Int(clippedEnd.timeIntervalSince(clippedStart) / 60)
            if session.kind == .work {
                result.workMinutes += minutes
            } else {
                result.breakMinutes += minutes
            }
            // Count a segment toward the counters of the day it ended in.
            guard session.completed, interval.contains(session.end) else { continue }
            switch session.kind {
            case .work:
                result.workSessions += 1
            case .shortBreak:
                result.loops += 1
            case .longBreak:
                result.loops += 1
                result.sprints += 1
            }
        }
        return result
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Session].self, from: data)
        else { return }
        sessions = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
