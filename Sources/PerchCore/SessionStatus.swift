import Foundation

public enum SessionState: String, Codable, Sendable {
    case working, waiting, ended
}

public struct SessionStatus: Codable, Identifiable, Sendable {
    public var id: String { sessionId }
    public let sessionId: String
    public let cwd: String
    public let project: String
    public let pid: Int32
    public let state: SessionState
    public let reason: String?
    public let startedAt: Double
    public let lastActivity: Double
    public let waitingSince: Double?
    public let host: String
    public let itermSessionId: String?
    public let tmuxPane: String?
    public let tty: String?
    /// Resolved terminal-tab title (e.g. the Claude session summary). Set by the
    /// app after decode via a TitleProvider; not part of the on-disk schema.
    public var displayName: String? = nil

    /// What the panel shows: the tab title when we have one, else the folder.
    public var name: String { displayName ?? project }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id", cwd, project, pid, state, reason
        case startedAt = "started_at", lastActivity = "last_activity"
        case waitingSince = "waiting_since", host
        case itermSessionId = "iterm_session_id", tmuxPane = "tmux_pane", tty
    }

    public init(sessionId: String, cwd: String, project: String, pid: Int32,
                state: SessionState, reason: String?, startedAt: Double,
                lastActivity: Double, waitingSince: Double?, host: String,
                itermSessionId: String?, tmuxPane: String?, tty: String?) {
        self.sessionId = sessionId; self.cwd = cwd; self.project = project
        self.pid = pid; self.state = state; self.reason = reason
        self.startedAt = startedAt; self.lastActivity = lastActivity
        self.waitingSince = waitingSince; self.host = host
        self.itermSessionId = itermSessionId; self.tmuxPane = tmuxPane; self.tty = tty
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        cwd = try c.decode(String.self, forKey: .cwd)
        project = try c.decode(String.self, forKey: .project)
        pid = try c.decode(Int32.self, forKey: .pid)
        state = try c.decode(SessionState.self, forKey: .state)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        startedAt = try c.decode(Double.self, forKey: .startedAt)
        lastActivity = try c.decodeIfPresent(Double.self, forKey: .lastActivity) ?? startedAt
        waitingSince = try c.decodeIfPresent(Double.self, forKey: .waitingSince)
        host = try c.decode(String.self, forKey: .host)
        itermSessionId = try c.decodeIfPresent(String.self, forKey: .itermSessionId)
        tmuxPane = try c.decodeIfPresent(String.self, forKey: .tmuxPane)
        tty = try c.decodeIfPresent(String.self, forKey: .tty)
    }

    public var episodeKey: String {
        "\(sessionId)|\(waitingSince.map { String(Int($0)) } ?? "-")"
    }

    public static func decode(from data: Data) throws -> SessionStatus {
        try JSONDecoder().decode(SessionStatus.self, from: data)
    }
}
