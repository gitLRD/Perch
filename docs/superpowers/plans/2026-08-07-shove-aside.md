# Shove-Aside Parking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user drag Perch out of the way; it stays put for 15 seconds then flies home to the top-right, instead of snapping back within a couple of seconds.

**Architecture:** A pure `ParkController` value type owns the parking deadline (unit-tested). `AppDelegate` becomes the panel's `NSWindowDelegate`, arms parking on user drags (distinguished from programmatic moves via a guard flag), skips repositioning while parked, and animates home on a 1s timer once the deadline elapses.

**Tech Stack:** Swift, AppKit (`NSPanel`, `NSWindowDelegate`), SwiftUI hosting. Tests run via the repo's plain-executable harness (`enum T`), not XCTest.

## Global Constraints

- Park duration is **15 seconds**, a single named constant.
- Home position is always top-right (existing `positionTopRight` math); no persisted custom home.
- No new dependencies. Tests use the existing `T` harness and are registered in `Tests/PerchTests/main.swift`.
- Build with `swift build`; run tests with `swift run PerchTests` (see how `main.swift` is wired).

---

### Task 1: `ParkController` value type + unit tests

**Files:**
- Create: `Sources/PerchCore/ParkController.swift`
- Create: `Tests/PerchTests/ParkControllerTests.swift`
- Modify: `Tests/PerchTests/main.swift` (register the new test function)

**Interfaces:**
- Produces:
  - `struct ParkController` with `static let parkDuration: TimeInterval` (== 15)
  - `var isParked: Bool { get }`
  - `mutating func didDrag(now: TimeInterval)`
  - `func shouldFlyHome(now: TimeInterval) -> Bool`
  - `mutating func reset()`

- [ ] **Step 1: Write the failing test**

Create `Tests/PerchTests/ParkControllerTests.swift`:

```swift
import Foundation
@testable import PerchCore

func parkControllerTests() {
    T.run("starts un-parked") {
        let p = ParkController()
        T.check(!p.isParked, "fresh controller is not parked")
        T.check(!p.shouldFlyHome(now: 1000), "un-parked never flies home")
    }

    T.run("didDrag arms parking for 15s") {
        var p = ParkController()
        p.didDrag(now: 100)
        T.check(p.isParked, "parked after drag")
        T.check(!p.shouldFlyHome(now: 114), "not home 1s before deadline")
        T.check(p.shouldFlyHome(now: 115), "home at deadline")
        T.check(p.shouldFlyHome(now: 200), "home after deadline")
    }

    T.run("a later drag pushes the deadline out") {
        var p = ParkController()
        p.didDrag(now: 100)
        p.didDrag(now: 110)          // re-arm
        T.check(!p.shouldFlyHome(now: 115), "old deadline no longer applies")
        T.check(p.shouldFlyHome(now: 125), "new deadline 110+15 applies")
    }

    T.run("reset clears parking") {
        var p = ParkController()
        p.didDrag(now: 100)
        p.reset()
        T.check(!p.isParked, "reset un-parks")
        T.check(!p.shouldFlyHome(now: 200), "reset stops fly-home")
    }

    T.run("parkDuration is 15") {
        T.equal(ParkController.parkDuration, 15, "duration constant")
    }
}
```

- [ ] **Step 2: Register the test and run it to verify it fails**

In `Tests/PerchTests/main.swift`, add a call to `parkControllerTests()` alongside the other test functions (match the existing call style there).

Run: `swift run PerchTests`
Expected: FAIL — `cannot find 'ParkController' in scope` (or the test asserts fail).

- [ ] **Step 3: Write minimal implementation**

Create `Sources/PerchCore/ParkController.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift run PerchTests`
Expected: PASS — `ok: ...` lines for each `parkControllerTests` case, overall suite exits 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/PerchCore/ParkController.swift Tests/PerchTests/ParkControllerTests.swift Tests/PerchTests/main.swift
git commit -m "feat: ParkController for shove-aside timing"
```

---

### Task 2: Wire parking into the panel + AppDelegate, remove dead autosave, update README

**Files:**
- Modify: `Sources/PerchCore/FloatingPanel.swift:28` (remove `setFrameAutosaveName`)
- Modify: `Sources/PerchCore/AppDelegate.swift` (delegate, guard flag, skip-while-parked, fly-home timer, show-un-parks)
- Modify: `README.md` (the "Move it — drag the panel anywhere; it remembers where you put it" bullet)

**Interfaces:**
- Consumes: `ParkController` (`didDrag(now:)`, `isParked`, `shouldFlyHome(now:)`, `reset()`) from Task 1.

- [ ] **Step 1: Remove the dead autosave name**

In `Sources/PerchCore/FloatingPanel.swift`, delete the line:

```swift
        setFrameAutosaveName("PerchPanel")
```

It never took effect (`positionTopRight()` always overrode it) and would now conflict with the parking model.

- [ ] **Step 2: Add parking state, the delegate, and the guard flag to `AppDelegate`**

In `Sources/PerchCore/AppDelegate.swift`, add stored properties near the other `private var`s (e.g. under `private let clock = LiveClock()`):

```swift
    private var park = ParkController()
    private var isProgrammaticMove = false
    private var parkTimer: Timer?
```

In `applicationDidFinishLaunching`, right after `panel.contentView = hosting`, make AppDelegate the panel's delegate:

```swift
        panel.delegate = self
```

- [ ] **Step 3: Guard `positionTopRight` and only reposition when not parked**

Replace the body of `positionTopRight()` so programmatic moves are flagged (so `windowDidMove` can ignore them):

```swift
    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        isProgrammaticMove = true
        panel.setFrameOrigin(NSPoint(x: vf.maxX - panel.frame.width - 16,
                                     y: vf.maxY - panel.frame.height - 16))
        isProgrammaticMove = false
    }
```

Then in `resizeToFit()`, skip repositioning while parked (still resize):

```swift
    private func resizeToFit() {
        let fit = hosting.fittingSize
        let height = max(90, fit.height)
        panel.setContentSize(NSSize(width: 262, height: height))
        if !park.isParked { positionTopRight() }
    }
```

- [ ] **Step 4: Arm parking on user drags and fly home on a timer**

Add the fly-home helper and start the timer. In `applicationDidFinishLaunching`, after the existing 30s reload timer block, add:

```swift
        parkTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.flyHomeIfDue() }
        }
```

Add these methods to `AppDelegate` (near `positionTopRight`):

```swift
    /// The panel has been parked long enough — animate it back to the corner.
    private func flyHomeIfDue() {
        guard park.isParked, park.shouldFlyHome(now: clock.now()) else { return }
        park.reset()
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let home = NSRect(x: vf.maxX - panel.frame.width - 16,
                          y: vf.maxY - panel.frame.height - 16,
                          width: panel.frame.width, height: panel.frame.height)
        isProgrammaticMove = true
        panel.setFrame(home, display: true, animate: true)
        isProgrammaticMove = false
        bird.poke()
    }
```

- [ ] **Step 5: Conform to `NSWindowDelegate` and un-park on show**

Add a `NSWindowDelegate` extension at the end of `AppDelegate.swift`:

```swift
extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        // Ignore our own repositioning / fly-home animation; only a real drag parks.
        guard !isProgrammaticMove else { return }
        park.didDrag(now: clock.now())
    }
}
```

In `showPanel()`, un-park so re-showing returns home. Change:

```swift
    private func showPanel() {
        park.reset()
        resizeToFit()
        panel.orderFrontRegardless()
        bird.poke()
        toggleItem?.title = "Hide Window"
    }
```

- [ ] **Step 6: Update the README bullet**

In `README.md`, replace:

```
- **Move it** — drag the panel anywhere; it remembers where you put it.
```

with:

```
- **Shove it aside** — drag the panel out of the way when it's covering something; the spot it leaves is instantly clickable. It flies back to the top-right after 15 seconds (each nudge resets the timer).
```

- [ ] **Step 7: Build, run tests, and verify the app launches**

Run: `swift build`
Expected: builds with no errors.

Run: `swift run PerchTests`
Expected: full suite passes (exit 0).

Then verify the behavior in the running app (the AppKit wiring can't be unit-tested): launch Perch, drag the panel away from the corner, confirm it stays, click something in the vacated top-right spot, and confirm the panel flies home ~15s after you release. See the `verify` / `run` skill for launching.

- [ ] **Step 8: Commit**

```bash
git add Sources/PerchCore/FloatingPanel.swift Sources/PerchCore/AppDelegate.swift README.md
git commit -m "feat: shove Perch aside; it flies home after 15s"
```

---

## Self-Review

- **Spec coverage:** stays-put-on-drag + no-snap-on-refresh (Task 2 Step 3), 15s fly-home (Task 1 + Task 2 Step 4), each drag resets (Task 1 `didDrag` re-arm), show returns home (Task 2 Step 5), dead-autosave cleanup (Task 2 Step 1), README (Task 2 Step 6). All covered.
- **Placeholders:** none — all steps carry real code.
- **Type consistency:** `ParkController` surface (`didDrag(now:)`, `isParked`, `shouldFlyHome(now:)`, `reset()`, `parkDuration`) used identically across both tasks. `clock.now()` matches the existing `LiveClock`/`Clock` API already used in `PerchView`.
