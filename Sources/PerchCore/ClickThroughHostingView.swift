import AppKit
import SwiftUI

/// Hosting view that accepts the *first* mouse click even when Perch isn't the
/// active window. Without this, clicking a row in the background panel only
/// focuses the window; you'd need a second click to actually trigger the jump.
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) { super.init(rootView: rootView) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
