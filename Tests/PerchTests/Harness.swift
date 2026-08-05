import Foundation

/// Minimal test harness — XCTest is unavailable under Command Line Tools, so
/// tests run as a plain executable that exits non-zero on any failure.
enum T {
    nonisolated(unsafe) static var failures = 0
    nonisolated(unsafe) static var checks = 0

    static func check(_ cond: Bool, _ msg: String, file: StaticString = #file, line: UInt = #line) {
        checks += 1
        if !cond {
            failures += 1
            print("  FAIL [\(file):\(line)]: \(msg)")
        }
    }

    static func equal<V: Equatable>(_ a: V, _ b: V, _ msg: String, file: StaticString = #file, line: UInt = #line) {
        check(a == b, "\(msg) — expected \(b), got \(a)", file: file, line: line)
    }

    static func run(_ name: String, _ body: () throws -> Void) {
        let before = failures
        do { try body() } catch { failures += 1; print("  FAIL \(name): threw \(error)") }
        print(failures == before ? "ok: \(name)" : "FAILED: \(name)")
    }

    static func finish() -> Never {
        print("\n\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }

    /// Load a JSON fixture bundled with the test runner.
    static func fixture(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try! Data(contentsOf: url)
    }
}
