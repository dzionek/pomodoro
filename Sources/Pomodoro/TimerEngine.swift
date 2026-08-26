import AppKit
import Foundation

/// Drives the sprint state machine.
///
/// Segments never start on their own: after one finishes the bell rings
/// and the engine waits in `.ringing`, then `.idle`, until the user
/// explicitly starts the next segment.
final class TimerEngine: ObservableObject {
    enum Phase: Equatable {
        case idle                   // waiting for the user to start `nextKind`
        case running(SegmentKind)
        case ringing(SegmentKind)   // segment finished, bell going, waiting for acknowledgement
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var now: Date = Date()
    @Published var config: Config {
        didSet { config.save() }
    }

    /// 1-based index of the loop we are in within the current sprint.
    @Published private(set) var currentLoop: Int
    /// The segment the user will start next.
    @Published private(set) var nextKind: SegmentKind

    let store: HistoryStore

    private(set) var segmentStart: Date?
    private(set) var segmentEnd: Date?

    private var ticker: Timer?
    private var bellTimer: Timer?
    private var bellRings = 0
    private let maxBellRings = 12

    private static let loopKey = "pomodoro.currentLoop"
    private static let nextKindKey = "pomodoro.nextKind"

    init(store: HistoryStore = HistoryStore()) {
        self.store = store
        self.config = Config.load()
        let savedLoop = UserDefaults.standard.integer(forKey: Self.loopKey)
        self.currentLoop = savedLoop > 0 ? savedLoop : 1
        if let raw = UserDefaults.standard.string(forKey: Self.nextKindKey),
           let kind = SegmentKind(rawValue: raw) {
            self.nextKind = kind
        } else {
            self.nextKind = .work
        }
    }

    var remainingSeconds: Int {
        guard let end = segmentEnd else { return 0 }
        return max(0, Int(end.timeIntervalSince(now).rounded()))
    }

    /// Menu bar text next to the tomato icon.
    var statusText: String {
        switch phase {
        case .idle:
            return ""
        case .running:
            return String(format: " %d:%02d", remainingSeconds / 60, remainingSeconds % 60)
        case .ringing(let kind):
            return " \(kind.label) done!"
        }
    }

    // MARK: - User actions

    func startNextSegment() {
        guard phase == .idle else { return }
        let kind = nextKind
        let start = Date()
        segmentStart = start
        segmentEnd = start.addingTimeInterval(TimeInterval(config.minutes(for: kind)) * 60)
        phase = .running(kind)
        startTicker()
    }

    /// Abandon the running segment without advancing the sprint.
    /// Time already spent is kept in the history so the calendar stays truthful.
    func cancelSegment() {
        guard case .running(let kind) = phase, let start = segmentStart else { return }
        let end = Date()
        if end.timeIntervalSince(start) >= 60 {
            store.add(Session(kind: kind, start: start, end: end, completed: false))
        }
        stopTicker()
        segmentStart = nil
        segmentEnd = nil
        phase = .idle
    }

    /// End a running break early and advance the sprint as if it had finished.
    /// Time already spent is kept in the history, marked incomplete.
    func skipBreak() {
        guard case .running(let kind) = phase, kind.isBreak, let start = segmentStart else { return }
        let end = Date()
        if end.timeIntervalSince(start) >= 60 {
            store.add(Session(kind: kind, start: start, end: end, completed: false))
        }
        stopTicker()
        segmentStart = nil
        segmentEnd = nil
        advancePosition(after: kind)
        phase = .idle
    }

    /// Silence the bell after a segment finished.
    func acknowledge() {
        guard case .ringing = phase else { return }
        stopBell()
        phase = .idle
    }

    /// Go back to the start of a fresh sprint. Cancels a running segment if any.
    func resetSprint() {
        if case .running = phase { cancelSegment() }
        stopBell()
        stopTicker()
        segmentStart = nil
        segmentEnd = nil
        currentLoop = 1
        nextKind = .work
        phase = .idle
        persistPosition()
    }

    /// Record whatever is in flight (called when the app quits mid-segment).
    func recordPartialOnQuit() {
        if case .running(let kind) = phase, let start = segmentStart {
            let end = Date()
            if end.timeIntervalSince(start) >= 60 {
                store.add(Session(kind: kind, start: start, end: end, completed: false))
            }
        }
    }

    // MARK: - Internals

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        now = Date()
        if case .running(let kind) = phase, let end = segmentEnd, now >= end {
            completeSegment(kind)
        }
    }

    private func completeSegment(_ kind: SegmentKind) {
        stopTicker()
        if let start = segmentStart, let end = segmentEnd {
            store.add(Session(kind: kind, start: start, end: end, completed: true))
        }
        segmentStart = nil
        segmentEnd = nil
        advancePosition(after: kind)
        phase = .ringing(kind)
        startBell()
    }

    private func advancePosition(after kind: SegmentKind) {
        switch kind {
        case .work:
            nextKind = currentLoop >= config.loopsPerSprint ? .longBreak : .shortBreak
        case .shortBreak:
            currentLoop += 1
            nextKind = .work
        case .longBreak:
            currentLoop = 1
            nextKind = .work
        }
        persistPosition()
    }

    private func persistPosition() {
        UserDefaults.standard.set(currentLoop, forKey: Self.loopKey)
        UserDefaults.standard.set(nextKind.rawValue, forKey: Self.nextKindKey)
    }

    // MARK: - Bell

    private func startBell() {
        bellRings = 0
        ringBell()
        let timer = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.ringBell()
        }
        RunLoop.main.add(timer, forMode: .common)
        bellTimer = timer
    }

    private func ringBell() {
        guard bellRings < maxBellRings else {
            stopBell()
            return
        }
        bellRings += 1
        if let sound = NSSound(named: "Glass") {
            sound.volume = 1.0
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func stopBell() {
        bellTimer?.invalidate()
        bellTimer = nil
    }
}
