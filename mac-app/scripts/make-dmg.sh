#!/bin/bash
# Builds TestForge.app (make-app.sh) and packs it into build/TestForge-<version>.dmg to share (D-132).
# The DMG holds only the app: on first launch its Setup screen asks for the person's own clone of the iOS repo,
# because tests build that code and the QA server lives in it (server/ in the blibli-testforge clone).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/make-app.sh" release
APP="$ROOT/build/TestForge.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/build/TestForge-$VERSION.dmg"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Read me first.txt" <<'TEXT'
TestForge — install

1. Drag TestForge into Applications.
2. Open it. The app is not notarised, so macOS stops the first launch:
   System Settings › Privacy & Security › "TestForge was blocked" › Open Anyway.
3. Setup asks for your blibli-testforge clone and your BlibliIOSApp clone
   and checks Xcode, Node.js 18+, Claude Code and your Claude sign-in. Fix anything red, then Continue.
4. The app reopens, starts its QA server and shows Get ready. Follow it top to bottom
   (Build for testing takes 15–20 min the first time).
5. The Claude section opens a Claude session in your repo — no Terminal needed after sign-in.
TEXT

rm -f "$DMG"
hdiutil create -volname "TestForge" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "dmg: $DMG"
