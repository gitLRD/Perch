import Foundation
@testable import PerchCore

func sessionStatusTests() {
    T.run("decode waiting") {
        let s = try SessionStatus.decode(from: T.fixture("waiting"))
        T.equal(s.sessionId, "abc", "sessionId")
        T.equal(s.state, .waiting, "state")
        T.equal(s.project, "whatsapp-bot", "project")
        T.equal(s.waitingSince, 1785593571.3, "waitingSince")
        T.equal(s.host, "cmux", "host")
        T.equal(s.episodeKey, "abc|1785593571", "episodeKey")
    }
    T.run("decode working has no waiting_since") {
        let s = try SessionStatus.decode(from: T.fixture("working"))
        T.equal(s.state, .working, "state")
        T.check(s.waitingSince == nil, "waitingSince nil")
        T.equal(s.episodeKey, "def|-", "episodeKey")
    }
}
