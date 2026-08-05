#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; . "$DIR/_perch-common.sh"
payload="$(cat)"
sid="$(printf '%s' "$payload" | perch_stdin_field session_id)"
cwd="$(printf '%s' "$payload" | perch_stdin_field cwd)"; [ -n "$cwd" ] || cwd="$PWD"
perch_write "$sid" waiting "$cwd"
