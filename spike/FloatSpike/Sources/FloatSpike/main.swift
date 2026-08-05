import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let panel = NSPanel(
    contentRect: NSRect(x: 200, y: 200, width: 220, height: 120),
    styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
    backing: .buffered, defer: false)
panel.isFloatingPanel = true
panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
panel.hidesOnDeactivate = false
panel.title = "Perch spike"
panel.backgroundColor = NSColor.systemOrange

let label = NSTextField(labelWithString: "If you can see me over a fullscreen app, PASS")
label.frame = NSRect(x: 12, y: 40, width: 196, height: 40)
label.maximumNumberOfLines = 3
label.textColor = .white
panel.contentView?.addSubview(label)
panel.orderFrontRegardless()
app.run()
