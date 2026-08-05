import Foundation
@testable import PerchCore

private struct StubCmux: CmuxLookup {
    let map: [String: CmuxSurface]
    func surface(for id: String) -> CmuxSurface? { map[id] }
}
private func mkJ(_ id: String, host: String, iterm: String? = nil, pane: String? = nil) -> SessionStatus {
    SessionStatus(sessionId: id, cwd: "/x/\(id)", project: id, pid: 1, state: .waiting,
                  reason: nil, startedAt: 0, lastActivity: 0, waitingSince: 1,
                  host: host, itermSessionId: iterm, tmuxPane: pane, tty: nil)
}

func jumpDispatcherTests() {
    T.run("cmux builds select, focus, then raises the app") {
        let d = JumpDispatcher(cmux: StubCmux(map: ["a": CmuxSurface(surfaceId: "S", workspaceId: "W")]))
        let cmd = d.command(for: mkJ("a", host: "cmux"))
        T.check(cmd == .sequence([
            .shell(["cmux", "select-workspace", "--workspace", "W"]),
            .shell(["cmux", "focus-panel", "--panel", "S", "--workspace", "W"]),
            .shell(["open", "-b", "com.cmuxterm.app"])
        ]), "cmux sequence")
    }
    T.run("cmux missing registry falls back to raising the app") {
        let d = JumpDispatcher(cmux: StubCmux(map: [:]))
        T.check(d.command(for: mkJ("a", host: "cmux")) == .shell(["open", "-b", "com.cmuxterm.app"]), "cmux fallback")
    }
    T.run("iterm builds applescript") {
        let d = JumpDispatcher(cmux: StubCmux(map: [:]))
        if case let .appleScript(src) = d.command(for: mkJ("a", host: "iterm2", iterm: "w0t0p0:GUID")) {
            T.check(src.contains("w0t0p0:GUID"), "applescript has session id")
            T.check(src.contains("iTerm"), "applescript targets iTerm")
        } else { T.check(false, "expected appleScript") }
    }
    T.run("tmux builds select-pane") {
        let d = JumpDispatcher(cmux: StubCmux(map: [:]))
        T.check(d.command(for: mkJ("a", host: "tmux", pane: "%3")) == .shell(["tmux", "select-pane", "-t", "%3"]),
                "tmux select-pane")
    }
    T.run("vscode best effort opens cwd") {
        let d = JumpDispatcher(cmux: StubCmux(map: [:]))
        T.check(d.command(for: mkJ("a", host: "vscode")) == .shell(["code", "/x/a"]), "vscode open")
    }
    T.run("dry run renders commands without executing") {
        let d = JumpDispatcher(cmux: StubCmux(map: ["a": CmuxSurface(surfaceId: "S", workspaceId: "W")]))
        let rendered = d.run(d.command(for: mkJ("a", host: "cmux")), dryRun: true)
        T.equal(rendered, ["cmux select-workspace --workspace W",
                           "cmux focus-panel --panel S --workspace W",
                           "open -b com.cmuxterm.app"], "dry run output")
    }
}
