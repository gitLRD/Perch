#!/usr/bin/env bash
# PreToolUse: a tool is about to run, so Claude is actively working. Assert
# "working" the instant a tool starts — this is what keeps a long-running
# command (e.g. a slow shell command) showing "working" for its whole
# duration, and clears a stale "waiting" left by an earlier notification or
# question prompt. The end-of-turn Stop hook still has the final say.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; . "$DIR/_perch-common.sh"
payload="$(cat)"
sid="$(printf '%s' "$payload" | perch_stdin_field session_id)"
cwd="$(printf '%s' "$payload" | perch_stdin_field cwd)"; [ -n "$cwd" ] || cwd="$PWD"
perch_write "$sid" working "$cwd"
