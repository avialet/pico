#!/bin/zsh
# Assemble build/Pico.app a partir du binaire SwiftPM (.build/<config>/Pico).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
BIN="$ROOT/.build/$CONFIG/Pico"
APP="$ROOT/build/Pico.app"
VERSION="$(grep -m1 MARKETING_VERSION "$ROOT/project.yml" | sed 's/.*"\(.*\)".*/\1/')"

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
    -e "s/<string>1.0<\/string>/<string>$VERSION<\/string>/" \
    "$ROOT/Pico/Resources/Info.plist" > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [ -d "$ROOT/Pico/Resources/Assets.xcassets" ] && command -v actool >/dev/null 2>&1; then
  actool --compile "$APP/Contents/Resources" --platform macosx --minimum-deployment-target 26.0 \
    --app-icon AppIcon --output-partial-info-plist /dev/null "$ROOT/Pico/Resources/Assets.xcassets" >/dev/null 2>&1 || true
fi
codesign --force --sign - --entitlements "$ROOT/Pico/Resources/Pico.entitlements" "$APP" 2>&1 | grep -v "replacing existing signature" || true
echo "-> $APP"
