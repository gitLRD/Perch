import AppKit

/// A non-activating panel that floats above everything — including another
/// app's native-fullscreen Space. Level + collectionBehavior confirmed in the
/// Task 0 spike.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        isReleasedWhenClosed = false
        setFrameAutosaveName("PerchPanel")
    }

    // Rows need to receive clicks, but the app itself never activates.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
