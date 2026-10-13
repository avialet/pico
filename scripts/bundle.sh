#!/bin/zsh
# Assemble build/Pico.app a partir du binaire SwiftPM (.build/<config>/Pico).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
BIN="$ROOT/.build/$CONFIG/Pico"
APP="$ROOT/build/Pico.app"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pico"
# Bundles de ressources SwiftPM (ex. KeyboardShortcuts_KeyboardShortcuts.bundle)
for b in "$ROOT"/.build/"$CONFIG"/*.bundle(N); do
  [ -d "$b" ] && cp -R "$b" "$APP/Contents/Resources/"
done
sed -e 's/$(EXECUTABLE_NAME)/Pico/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/fr.vialet.pico/g' \
    -e 's/$(DEVELOPMENT_LANGUAGE)/fr/g' \
    "$ROOT/Pico/Resources/Info.plist" > "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [ -f "$ROOT/Pico/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Pico/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi
codesign --force --sign - --entitlements "$ROOT/Pico/Resources/Pico.entitlements" "$APP" 2>&1 | grep -v "replacing existing signature" || true
echo "-> $APP"
