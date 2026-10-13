#!/bin/zsh
# Fabrique build/Pico-X.Y.Z.dmg et son checksum a partir de build/Pico.app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
APP="$ROOT/build/Pico.app"
DMG="$ROOT/build/Pico-$VERSION.dmg"
STAGE="$ROOT/build/dmg-stage"

[ -d "$APP" ] || { echo "build/Pico.app introuvable : lancez scripts/bundle.sh release" >&2; exit 1; }

# La version du noyau doit suivre VERSION.
CORE="$(grep -o 'version = "[^"]*"' "$ROOT/Packages/PicoCore/Sources/PicoCore/PicoCore.swift" | head -1 | sed 's/.*"\(.*\)"/\1/')"
[ "$CORE" = "$VERSION" ] || { echo "PicoCore.version ($CORE) differe de VERSION ($VERSION)" >&2; exit 1; }
BUILT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ "$BUILT" = "$VERSION" ] || { echo "Pico.app est en $BUILT, pas $VERSION : relancez bundle.sh" >&2; exit 1; }

rm -rf "$STAGE" "$DMG" "$DMG.sha256"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Pico.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Pico $VERSION" -srcfolder "$STAGE" -ov -format UDZO -fs HFS+ "$DMG" >/dev/null
rm -rf "$STAGE"
hdiutil verify "$DMG" >/dev/null
(cd "$ROOT/build" && shasum -a 256 "Pico-$VERSION.dmg" > "Pico-$VERSION.dmg.sha256")
echo "-> $DMG"
cat "$DMG.sha256"
