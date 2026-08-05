#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PERCH_DIR; PERCH_DIR="$(mktemp -d)"
export PERCH_PID=4321
fail=0
field() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$1" "$2"; }
assert() { if eval "$2"; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }

# SessionStart writes working, iterm2 host detected.
# Unset any ambient cmux/tmux markers so host detection is deterministic
# (the test itself may be running inside cmux or tmux).
echo '{"session_id":"s1","cwd":"/tmp/proj"}' | \
  env -u CMUX_SURFACE_ID -u CMUX_WORKSPACE_ID -u TMUX -u TMUX_PANE \
  TERM_PROGRAM=iTerm.app ITERM_SESSION_ID=w0t0p0:G "$DIR/perch-session-start.sh"
f="$PERCH_DIR/s1.json"
assert "start file exists"     "[ -f '$f' ]"
assert "state working"         "[ \"\$(field '$f' state)\" = working ]"
assert "host iterm2"           "[ \"\$(field '$f' host)\" = iterm2 ]"
assert "pid captured"          "[ \"\$(field '$f' pid)\" = 4321 ]"
started="$(field "$f" started_at)"

# Stop flips to waiting and sets waiting_since, preserves started_at
sleep 1
echo '{"session_id":"s1","cwd":"/tmp/proj"}' | "$DIR/perch-stop.sh"
assert "state waiting"         "[ \"\$(field '$f' state)\" = waiting ]"
assert "waiting_since present" "python3 -c 'import json;exit(0 if \"waiting_since\" in json.load(open(\"$f\")) else 1)'"
assert "started_at preserved"  "[ \"\$(field '$f' started_at)\" = '$started' ]"

# Notification with a permission message sets reason=permission
echo '{"session_id":"s1","cwd":"/tmp/proj","message":"Claude needs your permission to run"}' | "$DIR/perch-notification.sh"
assert "reason permission"     "[ \"\$(field '$f' reason)\" = permission ]"

# PostToolUse re-asserts working after an approved tool runs, clearing the
# stale "waiting" left by the permission prompt, and preserves started_at.
echo '{"session_id":"s1","cwd":"/tmp/proj"}' | "$DIR/perch-post-tool.sh"
assert "post-tool back to working" "[ \"\$(field '$f' state)\" = working ]"
assert "started_at still preserved" "[ \"\$(field '$f' started_at)\" = '$started' ]"

# A fresh notification re-stalls to waiting, then PreToolUse (a tool starting)
# asserts working — this keeps a long-running command showing working instead
# of the stale waiting a notification/question prompt left behind.
echo '{"session_id":"s1","cwd":"/tmp/proj","message":"Claude needs your permission"}' | "$DIR/perch-notification.sh"
assert "notification re-stalls waiting" "[ \"\$(field '$f' state)\" = waiting ]"
echo '{"session_id":"s1","cwd":"/tmp/proj"}' | "$DIR/perch-pre-tool.sh"
assert "pre-tool asserts working" "[ \"\$(field '$f' state)\" = working ]"

# Atomicity: no leftover temp files
assert "no temp files"         "[ -z \"\$(ls -a '$PERCH_DIR' | grep '^[.]s1[.]' || true)\" ]"

# cmux host detection
echo '{"session_id":"s2","cwd":"/tmp/p2"}' | CMUX_SURFACE_ID=SID CMUX_WORKSPACE_ID=WID "$DIR/perch-session-start.sh"
assert "host cmux"             "[ \"\$(field '$PERCH_DIR/s2.json' host)\" = cmux ]"

# SessionEnd marks ended
echo '{"session_id":"s2","cwd":"/tmp/p2"}' | "$DIR/perch-session-end.sh"
assert "state ended"           "[ \"\$(field '$PERCH_DIR/s2.json' state)\" = ended ]"

rm -rf "$PERCH_DIR"
[ "$fail" = 0 ] && echo "ALL HOOK TESTS PASSED" || echo "HOOK TESTS FAILED"
exit $fail
