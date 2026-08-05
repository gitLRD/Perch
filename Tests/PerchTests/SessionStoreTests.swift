import Foundation
@testable import PerchCore

private struct FakePids: PidChecker {
    let alive: Set<Int32>
    func isAlive(_ pid: Int32) -> Bool { alive.contains(pid) }
}
private struct FixedClock: Clock {
    let t: Double
    func now() -> Double { t }
}

func sessionStoreTests() {
    let fm = FileManager.default

    func freshDir() -> URL {
        let d = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! fm.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    func write(_ dir: URL, _ name: String, _ json: String) {
        try! json.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    func clearDismissed() {
        UserDefaults.standard.removeObject(forKey: "PerchDismissedEpisodes")
    }

    T.run("waiting sorts above working, dead pid dropped") {
        clearDismissed()
        let dir = freshDir()
        write(dir, "a.json", #"{"schema":1,"session_id":"a","cwd":"/x/alpha","project":"alpha","pid":10,"state":"working","started_at":1,"last_activity":1900,"host":"cmux"}"#)
        write(dir, "b.json", #"{"schema":1,"session_id":"b","cwd":"/x/bravo","project":"bravo","pid":11,"state":"waiting","started_at":1,"last_activity":1500,"waiting_since":1500,"host":"cmux"}"#)
        write(dir, "dead.json", #"{"schema":1,"session_id":"d","cwd":"/x/dead","project":"dead","pid":99,"state":"waiting","started_at":1,"last_activity":1000,"waiting_since":1000,"host":"cmux"}"#)
        let s = SessionStore(dir: dir, pids: FakePids(alive: [10, 11]), clock: FixedClock(t: 2000))
        s.reload()
        T.equal(s.sessions.map(\.sessionId), ["b", "a"], "waiting first, dead dropped")
    }

    T.run("dismiss hides current episode but not next one") {
        clearDismissed()
        let dir = freshDir()
        write(dir, "b.json", #"{"schema":1,"session_id":"b","cwd":"/x/bravo","project":"bravo","pid":11,"state":"waiting","started_at":1,"last_activity":1500,"waiting_since":1500,"host":"cmux"}"#)
        let s = SessionStore(dir: dir, pids: FakePids(alive: [11]), clock: FixedClock(t: 2000))
        s.reload()
        s.dismiss(s.sessions[0])
        s.reload()
        T.check(s.sessions.isEmpty, "same episode hidden after dismiss")
        write(dir, "b.json", #"{"schema":1,"session_id":"b","cwd":"/x/bravo","project":"bravo","pid":11,"state":"waiting","started_at":1,"last_activity":1800,"waiting_since":1800,"host":"cmux"}"#)
        s.reload()
        T.equal(s.sessions.map(\.sessionId), ["b"], "new waiting episode reappears")
        clearDismissed()
    }

    T.run("corrupt file skipped, others load") {
        clearDismissed()
        let dir = freshDir()
        write(dir, "good.json", #"{"schema":1,"session_id":"g","cwd":"/x/g","project":"g","pid":11,"state":"waiting","started_at":1,"last_activity":1,"waiting_since":1,"host":"cmux"}"#)
        write(dir, "bad.json", "{ this is not json")
        let s = SessionStore(dir: dir, pids: FakePids(alive: [11]), clock: FixedClock(t: 2000))
        s.reload()
        T.equal(s.sessions.map(\.sessionId), ["g"], "corrupt skipped")
    }
}
