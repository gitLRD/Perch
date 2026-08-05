import Foundation

public struct CmuxSurface: Equatable, Sendable {
    public let surfaceId: String
    public let workspaceId: String
    public init(surfaceId: String, workspaceId: String) {
        self.surfaceId = surfaceId
        self.workspaceId = workspaceId
    }
}

public protocol CmuxLookup: Sendable {
    func surface(for sessionId: String) -> CmuxSurface?
}

/// Reads cmux's own registry mapping Claude session_id → surface/workspace UUIDs.
public struct CmuxRegistry: CmuxLookup {
    let path: URL
    public init(path: URL = URL(fileURLWithPath: NSHomeDirectory() + "/.cmuxterm/claude-hook-sessions.json")) {
        self.path = path
    }
    public func surface(for sessionId: String) -> CmuxSurface? {
        guard let data = try? Data(contentsOf: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessions = root["sessions"] as? [String: Any],
              let s = sessions[sessionId] as? [String: Any],
              let surface = s["surfaceId"] as? String,
              let workspace = s["workspaceId"] as? String else { return nil }
        return CmuxSurface(surfaceId: surface, workspaceId: workspace)
    }
}
