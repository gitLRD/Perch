#!/usr/bin/env bash
# PostToolUse: a tool just ran, so Claude is actively working. Re-assert
# "working" — this clears a stale "waiting" left by a permission prompt once
# the user approves and work resumes. The end-of-turn Stop hook still has the
# final say and flips back to "waiting".
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; . "$DIR/_perch-common.sh"
payload="$(cat)"
sid="$(printf '%s' "$payload" | perch_stdin_field session_id)"
cwd="$(printf '%s' "$payload" | perch_stdin_field cwd)"; [ -n "$cwd" ] || cwd="$PWD"
perch_write "$sid" working "$cwd"
