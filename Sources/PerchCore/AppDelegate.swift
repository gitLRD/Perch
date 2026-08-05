import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var panel: FloatingPanel!
    private var hosting: NSHostingView<PerchView>!
    private var store: SessionStore!
    private let bird = BirdController()
    private var lastSignature = ""
    private var watcher: DirectoryWatcher!
    private var detector = TransitionDetector()
    private let notifier = Notifier()
    private var dispatcher: JumpDispatcher!
    private let clock = LiveClock()
    private let updater = Updater(currentVersion: PerchVersion)
    private var updateItem: NSMenuItem!
    private var updateURL: URL?

    private var perchDir: URL {
        let u = URL(fileURLWithPath: NSHomeDirectory() + "/.claude/perch")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.requestAuthorization()
        UNUserNotificationCenter.current().delegate = self

        store = SessionStore(dir: perchDir)
        dispatcher = JumpDispatcher(cmux: CmuxRegistry())

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        applyMenuBarIcon(waiting: 0)
        let menu = NSMenu()
        menu.delegate = self
        toggleItem = NSMenuItem(title: "Hide Window", action: #selector(togglePanel), keyEquivalent: "p")
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        updateItem = NSMenuItem(title: "Update available", action: #selector(openUpdate), keyEquivalent: "")
        updateItem.isHidden = true
        menu.addItem(updateItem)
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesManual), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Perch \(PerchVersion)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Perch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 262, height: 320))
        hosting = ClickThroughHostingView(rootView: PerchView(
            store: store,
            bird: bird,
            onJump: { [weak self] s in
                guard let self else { return }
                self.bird.poke()
                let dispatcher = self.dispatcher!
                let cmd = dispatcher.command(for: s)
                Log.write("onJump session=\(s.sessionId.prefix(8)) project=\(s.project) host=\(s.host) -> \(dispatcher.run(cmd, dryRun: true).joined(separator: " ; "))")
                DispatchQueue.global(qos: .userInitiated).async {
                    dispatcher.run(cmd, dryRun: false)
                }
            },
            onDismiss: { [weak self] s in self?.bird.poke(); self?.store.dismiss(s) },
            onClose: { [weak self] in self?.hidePanel() },
            clock: clock))
        panel.contentView = hosting
        resizeToFit()
        panel.orderFrontRegardless()

        watcher = DirectoryWatcher(url: perchDir) { [weak self] in self?.refresh() }
        refresh()

        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store.reload() }
        }

        // Auto-update: check on launch if a week has elapsed, then re-evaluate daily.
        if updater.checkDue() { runUpdateCheck(manual: false) }
        Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in if self?.updater.checkDue() == true { self?.runUpdateCheck(manual: false) } }
        }
    }

    @objc private func checkForUpdatesManual() { runUpdateCheck(manual: true) }

    @objc private func openUpdate() {
        NSWorkspace.shared.open(updateURL ?? Updater.releasesPage)
    }

    private func runUpdateCheck(manual: Bool) {
        updater.check { result in
            Task { @MainActor in self.handleUpdate(result, manual: manual) }
        }
    }

    private func handleUpdate(_ result: Updater.Result, manual: Bool) {
        switch result {
        case .updateAvailable(let tag, let url):
            updateURL = url
            updateItem.title = "⬆︎ Update available: \(tag)"
            updateItem.isHidden = false
            notifier.info(title: "Perch update available", body: "\(tag) is out — click to open the release.", url: url)
        case .upToDate(let v):
            updateItem.isHidden = true
            if manual { notifier.info(title: "Perch is up to date", body: "You're on the latest version (\(v)).") }
        case .failed(let why):
            if manual { notifier.info(title: "Couldn't check for updates", body: why) }
        }
    }

    private func refresh() {
        store.reload()
        for s in detector.newlyWaiting(store.sessions) { notifier.notify(s) }
        applyMenuBarIcon(waiting: store.sessions.filter { $0.state == .waiting }.count)
        // Nudge the bird only when the session set actually changes — not on
        // idle 30s reloads — so it moves "when something happens".
        let signature = store.sessions.map { "\($0.sessionId):\($0.state.rawValue)" }.joined(separator: ",")
        if signature != lastSignature {
            lastSignature = signature
            bird.poke()
        }
        resizeToFit()
    }

    /// Shrink the panel to the card's natural height so the transparent area
    /// below it isn't an invisible click-catcher.
    private func resizeToFit() {
        let fit = hosting.fittingSize
        let height = max(90, fit.height)
        panel.setContentSize(NSSize(width: 262, height: height))
        positionTopRight()
    }

    private func applyMenuBarIcon(waiting: Int) {
        guard let button = statusItem.button else { return }
        // Apple's SF Symbol renders a crisp, correctly-tinted bird in the menu
        // bar (white on a dark bar) — far more legible than a hand-drawn glyph.
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        if let img = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Perch")?
            .withSymbolConfiguration(config) {
            img.isTemplate = true
            button.image = img
            button.imagePosition = .imageLeading
            button.title = waiting > 0 ? " \(waiting)" : ""
        } else {
            button.image = nil
            button.title = waiting > 0 ? "🐦 \(waiting)" : "🐦"
        }
    }

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: vf.maxX - panel.frame.width - 16,
                                     y: vf.maxY - panel.frame.height - 16))
    }

    @objc func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func hidePanel() {
        panel.orderOut(nil)
        toggleItem?.title = "Show Window"
    }

    private func showPanel() {
        resizeToFit()
        panel.orderFrontRegardless()
        bird.poke()
        toggleItem?.title = "Hide Window"
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem?.title = panel.isVisible ? "Hide Window" : "Show Window"
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let id = info["sessionId"] as? String
        let urlString = info["url"] as? String
        Task { @MainActor in
            if let urlString, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            } else if let id, let s = self.store.sessions.first(where: { $0.sessionId == id }) {
                let dispatcher = self.dispatcher!
                let cmd = dispatcher.command(for: s)
                DispatchQueue.global(qos: .userInitiated).async { dispatcher.run(cmd, dryRun: false) }
            }
        }
        completionHandler()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
