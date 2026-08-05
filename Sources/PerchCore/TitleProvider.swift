import Foundation

/// Supplies a human-friendly title (the terminal tab title) for a session.
public protocol TitleProvider: Sendable {
    func title(for session: SessionStatus) -> String?
    /// Refresh the cache in the background, then call `completion` on the main thread.
    func refresh(completion: @escaping () -> Void)
}

/// Resolves the Claude session summary that cmux shows as the tab title, by
/// running `cmux tree` and matching the session's surface UUID (from the cmux
/// registry). Cached; refreshed off the main thread.
public final class CmuxTitleProvider: TitleProvider, @unchecked Sendable {
    private let cmux: CmuxLookup
    private let lock = NSLock()
    private var titlesBySurface: [String: String] = [:]

    public init(cmux: CmuxLookup) { self.cmux = cmux }

    public func title(for session: SessionStatus) -> String? {
        guard session.host == "cmux",
              let surface = cmux.surface(for: session.sessionId)?.surfaceId else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard let t = titlesBySurface[surface], !t.isEmpty, t != "Claude Code" else { return nil }
        return t
    }

    public func refresh(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async { [self] in
            let map = CmuxTitleProvider.fetch()
            lock.lock(); titlesBySurface = map; lock.unlock()
            DispatchQueue.main.async(execute: completion)
        }
    }

    /// Strip a leading status glyph / spinner (e.g. "✳ ", "⠂ ") and trim.
    static func clean(_ title: String) -> String {
        title.replacingOccurrences(of: "^[^\\p{L}\\p{N}]+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fetch() -> [String: String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["cmux", "tree", "--all", "--json", "--id-format", "both"]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return [:] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        var out: [String: String] = [:]
        func walk(_ o: Any) {
            if let d = o as? [String: Any] {
                if (d["type"] as? String) == "terminal",
                   let id = d["id"] as? String, let t = d["title"] as? String {
                    let c = clean(t)
                    if !c.isEmpty { out[id] = c }
                }
                for v in d.values { walk(v) }
            } else if let a = o as? [Any] {
                for v in a { walk(v) }
            }
        }
        walk(root)
        return out
    }
}
