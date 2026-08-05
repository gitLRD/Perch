import Foundation

public protocol PidChecker: Sendable {
    func isAlive(_ pid: Int32) -> Bool
}

public struct LivePidChecker: PidChecker {
    public init() {}
    public func isAlive(_ pid: Int32) -> Bool {
        if pid <= 0 { return false }
        // kill(pid, 0) == 0 → alive & signalable; EPERM → alive but owned by another user.
        return kill(pid, 0) == 0 || errno == EPERM
    }
}

public protocol Clock: Sendable {
    func now() -> Double
}

public struct LiveClock: Clock {
    public init() {}
    public func now() -> Double { Date().timeIntervalSince1970 }
}
