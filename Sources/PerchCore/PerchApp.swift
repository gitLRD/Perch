import AppKit

/// Public entrypoint used by the thin `Perch` executable.
public enum PerchApp {
    @MainActor private static var delegate: AppDelegate?

    @MainActor public static func main() {
        let app = NSApplication.shared
        let del = AppDelegate()
        delegate = del
        app.delegate = del
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
