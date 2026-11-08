#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="$PWD/build/Lunar.app"
codesign --verify --deep --strict "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
STAGE=$(mktemp -d "$PWD/build/package-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Lunar.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Lunar -srcfolder "$STAGE" -format UDZO -ov "$PWD/build/Lunar-$VERSION-arm64.dmg"
hdiutil verify "$PWD/build/Lunar-$VERSION-arm64.dmg"
(
  cd "$PWD/build"
  shasum -a 256 "Lunar-$VERSION-arm64.dmg" > "Lunar-$VERSION-arm64.dmg.sha256"
)
