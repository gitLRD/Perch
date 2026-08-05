#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="$HOME/.claude/hooks/perch"
mkdir -p "$DEST"
cp hooks/*.sh "$DEST/"
chmod +x "$DEST"/*.sh
SETTINGS="${PERCH_SETTINGS:-$HOME/.claude/settings.json}"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.perch.bak.$(date +%s)"

DEST="$DEST" python3 - "$SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]
dest = os.environ["DEST"]
try:
    with open(path) as f:
        cfg = json.load(f)
except Exception:
    cfg = {}
hooks = cfg.setdefault("hooks", {})
mapping = {
    "SessionStart":     "perch-session-start.sh",
    "UserPromptSubmit": "perch-user-prompt.sh",
    "PostToolUse":      "perch-post-tool.sh",
    "Stop":             "perch-stop.sh",
    "Notification":     "perch-notification.sh",
    "SessionEnd":       "perch-session-end.sh",
}
def already_present(arr, cmd):
    for entry in arr:
        for h in entry.get("hooks", []):
            if h.get("command") == cmd:
                return True
    return False

for event, script in mapping.items():
    cmd = f'bash "{dest}/{script}"'
    arr = hooks.setdefault(event, [])
    if already_present(arr, cmd):
        continue  # already installed — non-clobbering, idempotent
    arr.append({"hooks": [{"type": "command", "command": cmd}]})
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print("Installed Perch hooks into", path)
PY
