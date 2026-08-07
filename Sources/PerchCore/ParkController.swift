import Foundation

/// Tracks whether the user has shoved the panel aside and when it should
/// fly back home. Pure value type — no AppKit — so the timing is unit-testable.
/// `now` is injected (seconds, any monotonic-ish source) to keep it testable.
struct ParkController {
    /// How long the panel stays where the user dropped it before flying home.
    static let parkDuration: TimeInterval = 15

    /// Absolute time at which to fly home; nil means "at home / not parked".
    private var deadline: TimeInterval?

    var isParked: Bool { deadline != nil }

    /// Arm (or re-arm) parking. Call on every user-initiated window move.
    mutating func didDrag(now: TimeInterval) {
        deadline = now + Self.parkDuration
    }

    /// True once the park window has elapsed and the panel should return home.
    func shouldFlyHome(now: TimeInterval) -> Bool {
        guard let deadline else { return false }
        return now >= deadline
    }

    /// Clear parking — the panel is home (flew back, or forced home by show).
    mutating func reset() { deadline = nil }
}
