import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let engine = TimerEngine()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var statsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()


    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.tomatoIcon()
            button.imagePosition = .imageLeft
            // Monospaced digits so the countdown doesn't change width every
            // second, which would make the item (and an open popover) drift.
            button.font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize, weight: .regular)
            button.action = #selector(togglePopover)
            button.target = self
        }

        let root = PopoverView()
            .environmentObject(engine)
            .environmentObject(engine.store)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: root)
        popover.delegate = self

        // Keep the countdown in the menu bar in sync with the engine.
        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // While the popover is open the title must not change:
                // it would resize the status item and drag the popover
                // sideways. The pending text is applied on close.
                guard let self, !self.popover.isShown else { return }
                self.applyStatusText()
            }
            .store(in: &cancellables)

        // Pop the timer open when a segment finishes, so it is obvious
        // where the bell sound is coming from.
        engine.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self, case .ringing = phase, !self.popover.isShown else { return }
                self.openPopover()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: .openStatistics, object: nil, queue: .main
        ) { [weak self] _ in
            self?.showStatistics()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.recordPartialOnQuit()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        // macOS 26 Tahoe misplaces status-item popovers on first show
        // (FB20525595); showing twice in a row positions it correctly.
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverDidClose(_ notification: Notification) {
        applyStatusText()
    }

    private func applyStatusText() {
        let text = engine.statusText
        if statusItem.button?.title != text {
            statusItem.button?.title = text
        }
    }

    private func showStatistics() {
        popover.performClose(nil)
        if statsWindow == nil {
            let root = StatsView()
                .environmentObject(engine)
                .environmentObject(engine.store)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false)
            window.title = "Pomodoro — Statistics"
            window.contentView = NSHostingView(rootView: root)
            window.isReleasedWhenClosed = false
            window.center()
            statsWindow = window
        }
        statsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// A simple tomato drawn in code so we don't need an asset catalog.
    private static func tomatoIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let body = NSBezierPath(ovalIn: NSRect(x: 1.5, y: 0.5, width: 15, height: 13.5))
            NSColor.systemRed.setFill()
            body.fill()

            NSColor.systemGreen.setFill()
            let leaf = NSBezierPath()
            leaf.move(to: NSPoint(x: 9, y: 12))
            leaf.curve(to: NSPoint(x: 4.5, y: 15.5),
                       controlPoint1: NSPoint(x: 7.5, y: 14),
                       controlPoint2: NSPoint(x: 6, y: 15))
            leaf.curve(to: NSPoint(x: 9, y: 13.5),
                       controlPoint1: NSPoint(x: 6.5, y: 15.5),
                       controlPoint2: NSPoint(x: 8, y: 14.5))
            leaf.curve(to: NSPoint(x: 13.5, y: 15.5),
                       controlPoint1: NSPoint(x: 10, y: 14.5),
                       controlPoint2: NSPoint(x: 11.5, y: 15.5))
            leaf.curve(to: NSPoint(x: 9, y: 12),
                       controlPoint1: NSPoint(x: 12, y: 15),
                       controlPoint2: NSPoint(x: 10.5, y: 14))
            leaf.close()
            leaf.fill()

            let stem = NSBezierPath(
                rect: NSRect(x: 8.4, y: 12, width: 1.2, height: 4.5))
            NSColor.systemGreen.setFill()
            stem.fill()
            return true
        }
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
