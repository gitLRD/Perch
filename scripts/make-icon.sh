#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f assets/bird-1024.png ] || python3 scripts/make-bird.py
rm -rf assets/AppIcon.iconset
mkdir -p assets/AppIcon.iconset
for s in 16 32 64 128 256 512; do
  sips -z $s $s assets/bird-1024.png --out "assets/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) assets/bird-1024.png --out "assets/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns assets/AppIcon.iconset -o assets/AppIcon.icns
rm -rf assets/AppIcon.iconset
echo "wrote assets/AppIcon.icns"
