import Foundation
@testable import PerchCore

private struct StubTitles: TitleProvider {
    let map: [String: String]   // sessionId -> title
    func title(for s: SessionStatus) -> String? { map[s.sessionId] }
    func refresh(completion: @escaping () -> Void) { completion() }
}

func titleTests() {
    T.run("clean strips leading glyph/spinner") {
        T.equal(CmuxTitleProvider.clean("✳ Evaluate rsync scripts"), "Evaluate rsync scripts", "glyph")
        T.equal(CmuxTitleProvider.clean("⠂ Build Mac floating window"), "Build Mac floating window", "spinner")
        T.equal(CmuxTitleProvider.clean("LR Photo Identification"), "LR Photo Identification", "no glyph unchanged")
    }

    T.run("store applies title, falls back to folder") {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! fm.createDirectory(at: dir, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: "PerchDismissedEpisodes")
        func write(_ name: String, _ json: String) {
            try! json.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        write("a.json", #"{"schema":1,"session_id":"a","cwd":"/x/alpha","project":"alpha","pid":10,"state":"working","started_at":1,"last_activity":9,"host":"cmux"}"#)
        write("b.json", #"{"schema":1,"session_id":"b","cwd":"/x/bravo","project":"bravo","pid":11,"state":"working","started_at":1,"last_activity":8,"host":"cmux"}"#)
        struct AllAlive: PidChecker { func isAlive(_ p: Int32) -> Bool { true } }
        struct C: Clock { func now() -> Double { 100 } }
        let store = SessionStore(dir: dir, pids: AllAlive(), clock: C(),
                                 titles: StubTitles(map: ["a": "Build the thing"]))
        store.reload()
        let byId = Dictionary(uniqueKeysWithValues: store.sessions.map { ($0.sessionId, $0) })
        T.equal(byId["a"]!.name, "Build the thing", "a uses title")
        T.equal(byId["b"]!.name, "bravo", "b falls back to folder")
    }
}
