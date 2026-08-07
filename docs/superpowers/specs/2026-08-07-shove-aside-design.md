# Perch — "Shove aside, flies home after a spell" design

**Date:** 2026-08-07
**Status:** Approved (pending spec review)

## Problem

Perch floats over the top-right corner. Sometimes it sits on top of something the
user needs to click. When they drag it away, it snaps back to the top-right within
a couple of seconds, so they still can't get to what's underneath.

### Root cause

`AppDelegate.resizeToFit()` calls `positionTopRight()`, and `resizeToFit()` runs on
every `refresh()` — and each `refresh()` schedules a title-refresh callback that
calls `resizeToFit()` again. Refreshes are frequent (a 30s timer, directory-watcher
events, title refreshes), so any dragged position is force-overwritten almost
immediately. The `setFrameAutosaveName("PerchPanel")` "remembers where you put it"
behavior is effectively dead code because `positionTopRight()` always wins.

## Desired behavior

- **Drag Perch anywhere → it stays there.** The top-right spot it vacated is
  immediately clickable, because the window physically moved.
- **15 seconds after the user stops dragging, it animates back home** to the
  top-right corner.
- **Each drag restarts the 15s clock**, so nudging it again keeps it parked.
- **Refreshes no longer yank it home while parked** — they still resize the panel
  in place, but don't reposition it.
- **Re-showing from the menu (⌘P / Show Window) returns it home immediately**
  (un-parks).

Interaction model chosen: **park aside** (not click-through/ghost). Whatever spot
the panel lands on still blocks for the 15s, but the user chose a harmless spot;
the vacated home spot is what they wanted freed.

## Components

### 1. `ParkController` — new, pure value type (testable)

Owns parking state and timing. No AppKit dependency. Uses an injectable `now`
provider so the timing logic is unit-testable with the existing plain-executable
harness (mirrors the `Clock` / `LiveClock` pattern).

Approximate surface:

```swift
struct ParkController {
    private var deadline: TimeInterval?   // when to fly home; nil = at home
    static let parkDuration: TimeInterval = 15

    var isParked: Bool { deadline != nil }

    /// Arm/re-arm parking; call on every user-initiated window move.
    mutating func didDrag(now: TimeInterval) {
        deadline = now + Self.parkDuration
    }

    /// True once the park window has elapsed.
    func shouldFlyHome(now: TimeInterval) -> Bool {
        guard let deadline else { return false }
        return now >= deadline
    }

    /// Clear parking (returned home, or forced home by show).
    mutating func reset() { deadline = nil }
}
```

### 2. `AppDelegate` wiring

- Set `panel.delegate = self`; conform to `NSWindowDelegate`.
- `windowDidMove(_:)` distinguishes a **user drag** from **our own**
  `setFrameOrigin` / animated home moves via an `isProgrammaticMove` guard flag.
  A user drag calls `park.didDrag(now:)`.
- `positionTopRight()` sets `isProgrammaticMove = true` around its
  `setFrameOrigin`, and the animated fly-home does the same, so programmatic
  moves never arm parking.
- `resizeToFit()` skips `positionTopRight()` while `park.isParked` (still calls
  `setContentSize`).
- A lightweight repeating timer (~1s) checks `park.shouldFlyHome(now:)`; when true
  it animates the panel home with `setFrame(_:display:animate:)` (a gentle
  "fly back" that fits the bird's personality) and calls `park.reset()`.
- `showPanel()` calls `park.reset()` so re-showing goes home.

### 3. Cleanup (in scope)

- Remove the dead `setFrameAutosaveName("PerchPanel")` from `FloatingPanel`.
- Update the README bullet "drag the panel anywhere; it remembers where you put
  it" to describe the shove-aside-for-15s behavior.

## Out of scope

- No click-through / ghost mode.
- No persistence of a custom home position (home is always top-right).
- No user-facing config for the duration (hard-coded 15s constant, easy to tweak).

## Testing

**Unit tests (`ParkController`)** via the existing harness:
- `didDrag` arms parking (`isParked == true`).
- Not `shouldFlyHome` before the deadline.
- `shouldFlyHome` true at/after `now + 15`.
- A second `didDrag` pushes the deadline out (drag resets the clock).
- `reset` clears parking.

**Manual / build verification** for the AppKit wiring (`windowDidMove` guard,
skip-reposition-while-parked, animated fly-home, show-un-parks) — the harness
can't drive real window drags, so this is verified by building and running.
