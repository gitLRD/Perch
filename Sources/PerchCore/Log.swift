import Foundation

/// Lightweight append-only log at ~/.claude/perch/perch.log for diagnosing
/// jump behaviour without attaching a debugger.
enum Log {
    static let url = URL(fileURLWithPath: NSHomeDirectory() + "/.claude/perch/perch.log")

    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            h.seekToEndOfFile()
            h.write(data)
        } else {
            try? data.write(to: url)
        }
    }
}
