# 🐦 Perch

A native macOS floating mini-window that shows **which Claude Code sessions are waiting on you** across all your terminals — so nothing sits idle waiting for input while you're heads-down elsewhere (even in a fullscreen app).

- **Who's waiting on you**, sorted to the top and styled loudest (amber). Working sessions dim below (green).
- **Floats over everything**, including another app's native-fullscreen Space, without stealing focus.
- **Alerts** with a native notification the moment a session transitions from working → waiting.
- **Click to jump** to the terminal that needs you. First-class for **cmux**; also iTerm2, tmux, and best-effort VS Code.
- **Dismiss** a session as finished — it reappears if it does more work and stops again.

## How it works

Three decoupled pieces talk through the filesystem:

1. **Hooks** (`hooks/`) — Claude Code runs these on `SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`, and `SessionEnd`. Each writes one atomic JSON status file to `~/.claude/perch/<session_id>.json` recording state (`working`/`waiting`/`ended`), project, pid, and host + jump coordinates.
2. **Perch.app** (`Sources/`) — a menu-bar app (no Dock icon) that watches `~/.claude/perch/` with FSEvents, renders the floating panel, fires notifications on transition, and reconciles dead sessions by pid.
3. **Jump dispatcher** — on click, raises the right terminal. For cmux it resolves `session_id → surfaceId/workspaceId` from cmux's own `~/.cmuxterm/claude-hook-sessions.json` and calls `cmux select-workspace` + `cmux focus-panel`.

## Requirements

- macOS 13+
- Swift 6 toolchain (Command Line Tools is enough — **no full Xcode required**)
- python3 (ships with macOS) for the hooks and installer

## Build & install

```bash
# 1. Run the tests (unit + hook)
swift run PerchTestRunner
./hooks/tests/run-hook-tests.sh

# 2. Generate assets + build the .app bundle
./scripts/make-icon.sh          # bird icon (optional; falls back to SF Symbol)
./scripts/package-app.sh        # produces Perch.app (ad-hoc signed)

# 3. Install the status-feed hooks into ~/.claude/settings.json
#    (merges with your existing hooks; makes a timestamped backup first)
./scripts/install-hooks.sh

# 4. Launch
open Perch.app
```

To keep it always on: drag `Perch.app` to `/Applications` and add it as a **Login Item** (System Settings → General → Login Items).

The hooks take effect for **new** Claude Code sessions started after install. Grant notification permission when macOS prompts, so alerts can appear.

## Per-host jump support

| Host       | Behaviour |
|------------|-----------|
| **cmux**   | First-class: focuses the exact surface via the `cmux` CLI. |
| iTerm2     | AppleScript selects the session by `ITERM_SESSION_ID`. |
| tmux       | `tmux select-pane -t <pane>`. |
| VS Code    | Best-effort: opens the workspace folder (`code <cwd>`); a specific integrated-terminal panel isn't reliably targetable. |

## Uninstall

```bash
rm -rf ~/.claude/hooks/perch          # remove hook scripts
rm -rf ~/.claude/perch                # remove status files
# restore the settings backup written by the installer:
ls ~/.claude/settings.json.perch.bak.*   # pick the newest and copy it back
```

## Development

- Logic lives in the `PerchCore` library; `Perch` is a thin executable entrypoint.
- Tests run as a plain executable (`PerchTestRunner`) with a minimal assert harness, because XCTest isn't available under Command Line Tools. Add a suite function and call it from `Tests/PerchTests/main.swift`.
- The floating-over-fullscreen behaviour uses `CGShieldingWindowLevel()` + `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` on a `.nonactivatingPanel` (see `FloatingPanel.swift`).
