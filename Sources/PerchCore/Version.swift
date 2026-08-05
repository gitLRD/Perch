import Foundation

/// The app's version, read from the bundle's CFBundleShortVersionString with a
/// build-time fallback so it also works when run un-bundled (e.g. tests).
public let PerchVersion: String =
    (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.2.5"
