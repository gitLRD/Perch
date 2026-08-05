#!/usr/bin/env bash
# Assemble a self-contained Perch distribution: the .app, the hooks, and a
# one-step install.sh. Produces dist/Perch/ and Perch-<version>-macos.zip.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-0.1.0}"
./scripts/make-icon.sh >/dev/null 2>&1 || true
./scripts/package-app.sh >/dev/null

STAGE="dist/Perch"
rm -rf dist && mkdir -p "$STAGE/hooks"
cp -R Perch.app "$STAGE/Perch.app"
cp hooks/*.sh "$STAGE/hooks/"
cp README.md "$STAGE/README.md"

cat > "$STAGE/install.sh" <<'INSTALL'
#!/usr/bin/env bash
# One-step Perch installer for a downloaded release.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "→ Removing quarantine flag from Perch.app…"
xattr -dr com.apple.quarantine "$HERE/Perch.app" 2>/dev/null || true

echo "→ Installing status hooks into ~/.claude …"
DEST="$HOME/.claude/hooks/perch"
mkdir -p "$DEST"
cp "$HERE/hooks/"*.sh "$DEST/"
chmod +x "$DEST"/*.sh
SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.perch.bak.$(date +%s)"
DEST="$DEST" python3 - "$SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]; dest = os.environ["DEST"]
try:
    with open(path) as f: cfg = json.load(f)
except Exception:
    cfg = {}
hooks = cfg.setdefault("hooks", {})
mapping = {
    "SessionStart": "perch-session-start.sh", "UserPromptSubmit": "perch-user-prompt.sh",
    "Stop": "perch-stop.sh", "Notification": "perch-notification.sh", "SessionEnd": "perch-session-end.sh",
}
def present(arr, cmd):
    return any(h.get("command") == cmd for e in arr for h in e.get("hooks", []))
for event, script in mapping.items():
    cmd = f'bash "{dest}/{script}"'
    arr = hooks.setdefault(event, [])
    if not present(arr, cmd):
        arr.append({"hooks": [{"type": "command", "command": cmd}]})
with open(path, "w") as f: json.dump(cfg, f, indent=2)
print("   hooks installed (existing hooks preserved; backup written)")
PY

echo "→ Moving Perch.app to /Applications …"
if cp -R "$HERE/Perch.app" /Applications/ 2>/dev/null; then
  APP="/Applications/Perch.app"
else
  mkdir -p "$HOME/Applications"; cp -R "$HERE/Perch.app" "$HOME/Applications/"; APP="$HOME/Applications/Perch.app"
fi
open "$APP"
echo
echo "✓ Perch installed. Look for the owl 🦉 in your menu bar (top-right)."
echo "  Hooks take effect for NEW Claude Code sessions. Grant notifications when asked."
INSTALL
chmod +x "$STAGE/install.sh"

ZIP="Perch-${VERSION}-macos.zip"
rm -f "$ZIP"
( cd dist && ditto -c -k --keepParent Perch "../$ZIP" )
echo "Built $ZIP"
