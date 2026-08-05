import Foundation

public enum JumpCommand: Equatable, Sendable {
    case shell([String])
    case appleScript(String)
    case sequence([JumpCommand])
    case none(String)
}

/// Builds (and optionally runs) the command that raises the terminal a session
/// lives in. Building is pure and unit-tested; `run` has a dry-run mode.
public struct JumpDispatcher {
    let cmux: CmuxLookup

    public init(cmux: CmuxLookup) { self.cmux = cmux }

    public func command(for s: SessionStatus) -> JumpCommand {
        switch s.host {
        case "cmux":
            guard let surf = cmux.surface(for: s.sessionId) else {
                return .shell(["open", "-a", "cmux"])
            }
            return .sequence([
                .shell(["cmux", "select-workspace", "--workspace", surf.workspaceId]),
                .shell(["cmux", "focus-panel", "--panel", surf.surfaceId, "--workspace", surf.workspaceId]),
            ])
        case "iterm2":
            let sid = s.itermSessionId ?? ""
            let script = """
            tell application "iTerm2"
              activate
              repeat with w in windows
                repeat with t in tabs of w
                  repeat with ss in sessions of t
                    if id of ss is "\(sid)" then
                      select w
                      select t
                      select ss
                    end if
                  end repeat
                end repeat
              end repeat
            end tell
            """
            return .appleScript(script)
        case "tmux":
            guard let pane = s.tmuxPane else { return .none("no tmux pane recorded") }
            return .shell(["tmux", "select-pane", "-t", pane])
        case "vscode":
            return .shell(["code", s.cwd])
        default:
            return .none("unknown host \(s.host)")
        }
    }

    @discardableResult
    public func run(_ c: JumpCommand, dryRun: Bool) -> [String] {
        switch c {
        case .shell(let args):
            let line = args.joined(separator: " ")
            if !dryRun { runProcess(args) }
            return [line]
        case .appleScript(let src):
            if !dryRun { runProcess(["osascript", "-e", src]) }
            return ["osascript"]
        case .sequence(let cmds):
            return cmds.flatMap { run($0, dryRun: dryRun) }
        case .none(let why):
            return ["# skipped: \(why)"]
        }
    }

    private func runProcess(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        // GUI apps launched via `open` inherit a minimal PATH that omits
        // Homebrew, so `cmux` / `code` / `tmux` wouldn't resolve. Prepend the
        // usual tool locations.
        var env = ProcessInfo.processInfo.environment
        let toolPaths = "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin"
        env["PATH"] = toolPaths + ":" + (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        p.environment = env
        try? p.run()
    }
}
