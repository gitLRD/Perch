import SwiftUI
import AppKit

/// The comical bird. Loads an animated GIF from the app bundle; falls back to
/// the SF Symbol `bird` when the asset is missing (e.g. during early builds).
struct BirdView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        if let url = Bundle.main.url(forResource: "bird", withExtension: "gif"),
           let img = NSImage(contentsOf: url) {
            v.image = img
            v.animates = true
        } else {
            v.image = NSImage(systemSymbolName: "bird", accessibilityDescription: "Perch")
            v.contentTintColor = .systemOrange
        }
        return v
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
