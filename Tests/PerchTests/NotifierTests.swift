import Foundation
@testable import PerchCore

private func mkT(_ id: String, _ state: SessionState, waiting: Double?) -> SessionStatus {
    SessionStatus(sessionId: id, cwd: "/x/\(id)", project: id, pid: 1, state: state,
                  reason: nil, startedAt: 0, lastActivity: 0, waitingSince: waiting,
                  host: "cmux", itermSessionId: nil, tmuxPane: nil, tty: nil)
}

func notifierTests() {
    T.run("fires once per new waiting episode") {
        var d = TransitionDetector()
        T.equal(d.newlyWaiting([mkT("a", .working, waiting: nil)]).map(\.id), [], "working: no fire")
        T.equal(d.newlyWaiting([mkT("a", .waiting, waiting: 100)]).map(\.id), ["a"], "edge fires")
        T.equal(d.newlyWaiting([mkT("a", .waiting, waiting: 100)]).map(\.id), [], "no repeat")
        T.equal(d.newlyWaiting([mkT("a", .working, waiting: nil)]).map(\.id), [], "back to work")
        T.equal(d.newlyWaiting([mkT("a", .waiting, waiting: 200)]).map(\.id), ["a"], "new episode fires")
    }
}
