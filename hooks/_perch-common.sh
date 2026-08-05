#!/usr/bin/env bash
# Shared helpers for Perch hooks. Requires python3 (always present on macOS).
PERCH_DIR="${PERCH_DIR:-$HOME/.claude/perch}"

perch_detect_host() {
  if [ -n "${CMUX_SURFACE_ID:-}" ] || [ -n "${CMUX_WORKSPACE_ID:-}" ]; then echo cmux; return; fi
  case "${TERM_PROGRAM:-}" in
    iTerm.app) echo iterm2; return;;
    vscode)    echo vscode; return;;
  esac
  if [ -n "${TMUX:-}" ]; then echo tmux; return; fi
  echo unknown
}

# perch_write <session_id> <state> <cwd> [reason]
# Recomputes the whole status file each event, preserving started_at and the
# current waiting episode's waiting_since. Atomic: temp file in PERCH_DIR, then mv.
perch_write() {
  local sid="$1" state="$2" cwd="$3" reason="${4:-}"
  [ -n "$sid" ] || return 0
  mkdir -p "$PERCH_DIR"
  local host project tmp
  host="$(perch_detect_host)"
  project="$(basename "$cwd")"
  tmp="$(mktemp "$PERCH_DIR/.${sid}.XXXXXX")"

  PERCH_TMP="$tmp" PERCH_PREV="$PERCH_DIR/${sid}.json" \
  SID="$sid" STATE="$state" CWD="$cwd" PROJECT="$project" REASON="$reason" \
  HOST="$host" NOW="$(date +%s)" PID="${PERCH_PID:-$PPID}" \
  ITERM="${ITERM_SESSION_ID:-}" TMUXPANE="${TMUX_PANE:-}" TTY="$(tty 2>/dev/null || echo)" \
  python3 - <<'PY'
import json, os
prev = {}
try:
    with open(os.environ["PERCH_PREV"]) as f:
        prev = json.load(f)
except Exception:
    prev = {}
now = int(os.environ["NOW"])
state = os.environ["STATE"]
d = {
    "schema": 1,
    "session_id": os.environ["SID"],
    "cwd": os.environ["CWD"],
    "project": os.environ["PROJECT"],
    "pid": int(os.environ["PID"] or 0),
    "state": state,
    "started_at": prev.get("started_at", now),
    "last_activity": now,
    "host": os.environ["HOST"],
    "iterm_session_id": os.environ.get("ITERM") or None,
    "tmux_pane": os.environ.get("TMUXPANE") or None,
    "tty": os.environ.get("TTY") or None,
}
if state == "waiting":
    # keep waiting_since across repeated waiting events in the same episode
    d["waiting_since"] = prev.get("waiting_since", now) if prev.get("state") == "waiting" else now
    if os.environ.get("REASON"):
        d["reason"] = os.environ["REASON"]
with open(os.environ["PERCH_TMP"], "w") as f:
    json.dump(d, f)
PY
  mv -f "$tmp" "$PERCH_DIR/${sid}.json"
}

# Extract a top-level field from the hook's stdin JSON payload.
perch_stdin_field() {
  python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    d={}
print(d.get(sys.argv[1],""))' "$1"
}
