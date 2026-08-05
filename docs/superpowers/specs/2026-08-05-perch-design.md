# Perch — Design Spec

**Date:** 2026-08-05
**Status:** Approved (brainstorming complete)

## Purpose

A native macOS floating mini-window that shows, at a glance, **which Claude Code
sessions are waiting on me** across all my terminal sessions — so nothing sits
idle waiting for input while I'm heads-down in something else (often a fullscreen
app). The north-star job is *"who's waiting on me."* Secondary states (still
working, done/idle) are shown but de-emphasized.

Primary host is **cmux** (must work flawlessly). Secondary hosts: iTerm2, VS Code
integrated terminal, tmux.

## Success criteria

- A persistent, compact window floats above **all** windows — including over
  another app's native-fullscreen Space — without stealing keyboard focus when clicked.
- Sessions that have stopped and need input are sorted to the top and visually loudest.
- When a session *transitions* into "waiting," a native notification fires.
- Clicking a waiting session raises/focuses the terminal it lives in
  (reliable for cmux; best-effort for VS Code).
- A session can be manually dismissed as finished; it reappears if it later does
  more work and stops again.

## Non-goals (YAGNI)

- No history/analytics/logging of past sessions.
- No remote sessions (local machine only).
- No in-app configuration UI (settings via a small JSON/defaults if needed).
- No non-macOS support.
- No display of *what* an agent is doing beyond its state + project name.

## Architecture

Three decoupled pieces communicating through the filesystem (Approach A):

```
Claude Code session ──(hooks)──▶  ~/.claude/perch/<session_id>.json   (state feed)
                                          │
cmux ──(its own registry)──▶ ~/.cmuxterm/claude-hook-sessions.json    (jump coords, cmux only)
                                          │
                                          ▼
                                  Perch.app (SwiftUI)
                                   • FSEvents watcher
                                   • model + reconciliation
                                   • floating NSPanel UI
                                   • notifications on transition
                                   • click-to-jump dispatcher
```

Rationale for filesystem transport: hooks don't care whether the app is running;
state survives app restarts; every file is `cat`-inspectable for debugging; the
two halves (hooks, app) are testable in isolation.

### Component 1 — Status feed (hooks)

Small POSIX-sh scripts wired into `~/.claude/settings.json`, one atomic write per
event to `~/.claude/perch/<session_id>.json`. Written atomically (temp file +
`mv`) to avoid the watcher reading half-written JSON.

| Hook | Action |
|------|--------|
| `SessionStart` | Create/refresh file. Capture `session_id`, `cwd`, `pid`, `started_at`, host detection + jump coordinates (see below), `state:"working"`. |
| `UserPromptSubmit` | `state:"working"`, bump `last_activity`. |
| `Stop` | `state:"waiting"`, set `waiting_since` (Claude finished its turn → it's on the user). **Primary signal.** |
| `Notification` | `state:"waiting"`, set `waiting_since` if unset, record `reason` (permission prompt / idle). The "needs you now" flavor. |
| `SessionEnd` (if available) | `state:"ended"` (app then removes it). |

Hooks receive the Claude hook JSON on stdin (contains `session_id`,
`transcript_path`, `cwd`); host coordinates come from the environment.

**Host detection** (in `SessionStart`), recorded into the file:
- **cmux**: detected via cmux env markers and/or cross-reference by `session_id`
  in `~/.cmuxterm/claude-hook-sessions.json` → authoritative `surfaceId`.
- **iTerm2**: `$TERM_PROGRAM == iTerm.app`; record `$ITERM_SESSION_ID`.
- **VS Code**: `$TERM_PROGRAM == vscode`; record `cwd` (workspace) only.
- **tmux**: `$TMUX` set; record `$TMUX_PANE` and the socket.
- Fallback: record `tty`.

Status file schema (v1):
```json
{
  "schema": 1,
  "session_id": "…",
  "cwd": "/Users/…/project",
  "project": "project",
  "pid": 4046,
  "state": "waiting",              // working | waiting | ended
  "reason": "permission",          // optional, waiting only
  "started_at": 1785317701.4,
  "last_activity": 1785593571.3,
  "waiting_since": 1785593571.3,   // present when state=waiting
  "host": "cmux",                  // cmux | iterm2 | vscode | tmux | unknown
  "iterm_session_id": null,
  "tmux_pane": null,
  "tty": "/dev/ttys012"
}
```

### Component 2 — Perch.app (SwiftUI + AppKit)

Built as a **Swift Package Manager executable** wrapped into a `.app` bundle by a
packaging script (no Xcode required — full Xcode is not installed; Swift 6.3
toolchain is). LSUIElement app (no Dock icon) with a menu-bar item.

- **Watcher:** FSEvents (or `DispatchSource` on the dir) on `~/.claude/perch/`.
  On change, reload all files into the model. Debounce coalesced events (~150 ms).
- **Reconciliation:** on each refresh and on a periodic timer (~5 s), drop/grey
  sessions whose `pid` is no longer alive (`kill(pid, 0)`), and any `state:"ended"`.
- **Model:** list of sessions with derived sort key: waiting-first (oldest
  `waiting_since` first), then working, then ended; excludes dismissed episodes.
- **Notifications:** UserNotifications framework. Fire when a session's state
  transitions `working → waiting` (edge-triggered, tracked in-memory), never on
  reload of an already-waiting session.

### Component 3 — Floating panel + jump dispatcher

**Panel (the fullscreen-float requirement):**
- `NSPanel`, `styleMask` includes `.nonactivatingPanel` (clicks don't activate the
  app / don't steal focus).
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
- `level` set above the fullscreen layer — target
  `CGWindowLevelForKey(.overlayWindow)` / `CGShieldingWindowLevel()`-class so it
  renders over another app's native-fullscreen Space.
- `isMovableByWindowBackground = true`; remembers position in `UserDefaults`.
- **This is the known-fiddly part of AppKit.** The plan MUST begin with a small
  spike proving the panel genuinely hovers over another app's fullscreen Space
  before any UI is layered on top. If the plain approach fails, fallback lever:
  an `NSWindow` subclass forcing `canBecomeKey=false` and re-asserting level on
  `NSApplication.didChangeScreenParametersNotification` / space-change notifications.

**View:**
- Playful animated bird in the header (animated GIF via `NSImageView`, or a small
  SwiftUI frame animation). Static bird glyph for the menu-bar item + app icon
  (macOS app icons are static `.icns`).
- One compact row per session: status dot · project name · elapsed timer
  ("waiting 4m" / "working 1m"). Waiting = amber/red + top; working = green,
  dimmed; ended/idle = grey.
- Per-row **dismiss** control (X). Dismissal keyed to the current waiting episode
  `(session_id, waiting_since)`, stored in Perch's own `UserDefaults` — NOT in the
  session file. A dismissed session that later works and stops again gets a new
  `waiting_since` and therefore reappears.
- Empty state: the bird dozing + "All caught up."

**Jump dispatcher** (on row click, by `host`):
- **cmux** (primary): resolve `session_id → surfaceId` (from the file, or via
  `~/.cmuxterm/claude-hook-sessions.json`), then focus via the `cmux` CLI. Exact
  verb pinned during planning from the cmux CLI contract
  (`https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md`);
  candidates: `cmux open <cwd> --surface <id> --focus true`, or a dedicated
  surface/window focus verb (`focus-window` exists for windows).
- **iTerm2**: AppleScript selecting the session whose id matches `ITERM_SESSION_ID`,
  then `activate`.
- **tmux**: `tmux select-window`/`select-pane -t $TMUX_PANE`, then activate the
  host terminal app.
- **VS Code**: best-effort — activate VS Code and `code <cwd>`; a specific
  integrated terminal panel is not reliably targetable. Documented as such.
- Jump actions have a **dry-run mode** that logs the command instead of running it
  (for tests + debugging).

## Error handling

- Corrupt/half-written status file → skip that file this cycle, log, retry next event.
- `cmux`/`osascript`/`tmux` binary missing or jump command fails → surface a brief
  inline error on the row; never crash.
- Dead PID → session greyed then removed on reconciliation.
- Notification permission denied → app still works, just no alerts.
- cmux registry absent (cmux not running) → cmux jump falls back to activating the
  app by bundle id if possible, else no-op with inline error.

## Testing strategy

- **Hooks:** invoke each script with fixture stdin JSON + a controlled env; assert
  the emitted `<session_id>.json` matches expected (state, host, coordinates).
  Assert atomic write (no partial file visible).
- **App model:** point the watcher at a fixture directory of `.json` files; assert
  sort order, dismissed-episode filtering, dead-PID reconciliation, and that the
  `working → waiting` edge fires exactly one notification.
- **Jump dispatcher:** dry-run mode asserts the exact command string built per host
  from given coordinates.
- **Panel behavior:** manual verification checklist (floats over fullscreen,
  non-activating, all Spaces) — the fullscreen spike is the gating test.

## Deliverables

1. `hooks/` — the status-feed scripts + an installer that wires them into
   `~/.claude/settings.json` (merging, not clobbering existing gsd hooks).
2. `Perch/` — SwiftPM package (sources + tests).
3. `scripts/package-app.sh` — builds the `.app` bundle (Info.plist, icon, GIF asset).
4. `assets/` — the comical bird GIF + static menu-bar/app icon.
5. `README.md` — install + run.
