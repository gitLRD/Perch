import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐦"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide Perch", action: #selector(togglePanel), keyEquivalent: "p"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Perch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 320))
        panel.contentView = NSHostingView(rootView: Text("Perch").padding())
        positionTopRight()
        panel.orderFrontRegardless()
    }

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: vf.maxX - panel.frame.width - 16, y: vf.maxY - panel.frame.height - 16))
    }

    @objc func togglePanel() {
        panel.isVisible ? panel.orderOut(nil) : panel.orderFrontRegardless()
    }
}
