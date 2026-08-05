import Foundation
import Combine

public final class SessionStore: ObservableObject {
    @Published public private(set) var sessions: [SessionStatus] = []
    private let dir: URL
    private let pids: PidChecker
    private let clock: Clock
    private let defaultsKey = "PerchDismissedEpisodes"

    public init(dir: URL, pids: PidChecker = LivePidChecker(), clock: Clock = LiveClock()) {
        self.dir = dir
        self.pids = pids
        self.clock = clock
    }

    private var dismissed: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: defaultsKey) }
    }

    public func isDismissed(_ s: SessionStatus) -> Bool { dismissed.contains(s.episodeKey) }

    public func dismiss(_ s: SessionStatus) {
        dismissed.insert(s.episodeKey)
        reload()
    }

    public func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        let dismissedNow = dismissed
        var loaded: [SessionStatus] = []
        for f in files where f.pathExtension == "json" {
            guard let data = try? Data(contentsOf: f),
                  let s = try? SessionStatus.decode(from: data) else { continue }  // skip corrupt/half-written
            if s.state == .ended { continue }
            if !pids.isAlive(s.pid) { continue }
            if dismissedNow.contains(s.episodeKey) { continue }
            loaded.append(s)
        }
        sessions = sorted(loaded)
    }

    private func sorted(_ xs: [SessionStatus]) -> [SessionStatus] {
        func rank(_ s: SessionStatus) -> Int {
            switch s.state { case .waiting: return 0; case .working: return 1; case .ended: return 2 }
        }
        return xs.sorted { a, b in
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            if a.state == .waiting { return (a.waitingSince ?? 0) < (b.waitingSince ?? 0) }
            return a.lastActivity > b.lastActivity
        }
    }
}
