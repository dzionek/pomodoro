import Foundation

/// User-configurable sprint parameters.
/// A sprint = N loops of (work X min + break), where the break after
/// loops 1..N-1 is the short break (Y min) and the break after loop N
/// is the long break (Z min). After the long break a new sprint begins.
struct Config: Codable, Equatable {
    var workMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var loopsPerSprint: Int = 3
    var longBreakMinutes: Int = 15

    func minutes(for kind: SegmentKind) -> Int {
        switch kind {
        case .work: return workMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    static let defaultsKey = "pomodoro.config"

    static func load() -> Config {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return Config() }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Config.defaultsKey)
        }
    }
}

enum SegmentKind: String, Codable {
    case work
    case shortBreak
    case longBreak

    var isBreak: Bool { self != .work }

    var label: String {
        switch self {
        case .work: return "Work"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        }
    }
}

/// One recorded stretch of time spent in a segment.
/// `completed` is false for segments the user cancelled part-way through;
/// those still show on the calendar but don't advance counters.
struct Session: Codable, Identifiable {
    var id: UUID = UUID()
    var kind: SegmentKind
    var start: Date
    var end: Date
    var completed: Bool

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}
