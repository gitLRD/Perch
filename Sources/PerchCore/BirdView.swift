import SwiftUI
import AppKit

/// Drives the mascot's occasional motion. `poke()` triggers one play-through;
/// `alert()` triggers a longer, more emphatic flurry — used when a session goes
/// orange (waiting on you). Otherwise the bird sits still on its resting frame.
final class BirdController: ObservableObject {
    @Published var pulse: Int = 0
    @Published var alertPulse: Int = 0
    func poke() { pulse &+= 1 }
    func alert() { alertPulse &+= 1 }
}

/// The mascot — a bird looking down at your work. Sits on a static resting
/// frame; animates once through the GIF on load and whenever `pulse` changes,
/// then settles back to rest so it isn't distracting.
struct BirdView: NSViewRepresentable {
    var size: CGFloat = 24
    var pulse: Int = 0
    var alert: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: size),
            v.heightAnchor.constraint(equalToConstant: size),
        ])
        context.coordinator.configure(imageView: v, size: size)
        context.coordinator.lastPulse = pulse
        context.coordinator.lastAlert = alert
        context.coordinator.playOnce()   // move once on first load
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        // An alert (a session went orange) gets a flap + a single hop.
        if alert != context.coordinator.lastAlert {
            context.coordinator.lastAlert = alert
            context.coordinator.lastPulse = pulse   // don't also fire a plain poke this cycle
            context.coordinator.playAlert()
        } else if pulse != context.coordinator.lastPulse {
            context.coordinator.lastPulse = pulse
            context.coordinator.playOnce()
        }
    }

    @MainActor final class Coordinator {
        private weak var imageView: NSImageView?
        private var animated: NSImage?
        private var rest: NSImage?
        private let duration: Double = 0.85   // total GIF run; then settle to rest
        var lastPulse = -1
        var lastAlert = -1
        private var stopWork: DispatchWorkItem?

        func configure(imageView: NSImageView, size: CGFloat) {
            self.imageView = imageView
            if let url = Bundle.main.url(forResource: "bird", withExtension: "gif"),
               let a = NSImage(contentsOf: url) {
                a.size = NSSize(width: size, height: size)
                animated = a
            }
            if let url = Bundle.main.url(forResource: "bird-rest", withExtension: "png"),
               let r = NSImage(contentsOf: url) {
                r.size = NSSize(width: size, height: size)
                rest = r
            } else {
                rest = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Perch")
            }
            imageView.image = rest
        }

        func playOnce() {
            guard let iv = imageView, let a = animated else { return }
            stopWork?.cancel()
            iv.image = a
            iv.animates = true
            let w = DispatchWorkItem { [weak self] in
                guard let self, let iv = self.imageView else { return }
                iv.animates = false
                iv.image = self.rest
            }
            stopWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: w)
        }

        /// A session went orange: flap the wings and give a single hop.
        func playAlert() {
            playOnce()
            hop()
        }

        /// One springy hop up and back down, animated on the view's layer so it
        /// doesn't disturb layout.
        private func hop() {
            guard let iv = imageView else { return }
            iv.wantsLayer = true
            guard let layer = iv.layer else { return }
            let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
            hop.values = [0, 0.35 * Double(iv.bounds.height), 0, 0.12 * Double(iv.bounds.height), 0]
            hop.keyTimes = [0, 0.28, 0.56, 0.78, 1.0]
            hop.duration = 0.5
            hop.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeIn),
                CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeIn),
            ]
            layer.add(hop, forKey: "hop")
        }
    }
}
