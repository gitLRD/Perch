import Foundation
import UserNotifications

/// Edge detector: returns sessions that just entered a *new* waiting episode.
/// A waiting episode is identified by episodeKey (session_id + waiting_since),
/// so a session that works and stops again yields a fresh notification.
public struct TransitionDetector {
    private var seenWaitingEpisodes: Set<String> = []

    public init() {}

    public mutating func newlyWaiting(_ sessions: [SessionStatus]) -> [SessionStatus] {
        let currentWaiting = Set(sessions.filter { $0.state == .waiting }.map(\.episodeKey))
        let fresh = sessions.filter { $0.state == .waiting && !seenWaitingEpisodes.contains($0.episodeKey) }
        // Forget episodes no longer waiting so a later re-entry can fire again.
        seenWaitingEpisodes = currentWaiting
        return fresh
    }
}

public final class Notifier {
    public init() {}

    public static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func notify(_ s: SessionStatus) {
        let content = UNMutableNotificationContent()
        content.title = "\(s.project) is waiting"
        content.body = s.reason == "permission" ? "Needs your approval" : "Finished — waiting on you"
        content.sound = .default
        content.userInfo = ["sessionId": s.sessionId]
        let req = UNNotificationRequest(identifier: s.episodeKey, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
