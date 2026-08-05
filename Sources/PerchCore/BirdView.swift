import SwiftUI
import AppKit

/// The mascot — a bird looking down at your work. Loads the animated GIF from
/// the bundle; falls back to an SF Symbol if the asset is missing. The image's
/// size is pinned so it never overflows its SwiftUI frame.
struct BirdView: NSViewRepresentable {
    var size: CGFloat = 28

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.translatesAutoresizingMaskIntoConstraints = false
        // Let the SwiftUI frame drive layout, not the image's intrinsic size.
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        if let url = Bundle.main.url(forResource: "bird", withExtension: "gif"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: size, height: size)   // pin intrinsic size
            v.image = img
            v.animates = true
        } else {
            v.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Perch")
            v.contentTintColor = NSColor(red: 217/255, green: 119/255, blue: 87/255, alpha: 1)
        }
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: size),
            v.heightAnchor.constraint(equalToConstant: size),
        ])
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
