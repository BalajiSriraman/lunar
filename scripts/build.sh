#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="$PWD/build/Lunar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift scripts/icon.swift "$PWD/build/Lunar.iconset"
iconutil -c icns "$PWD/build/Lunar.iconset" -o "$APP/Contents/Resources/Lunar.icns"
swiftc -O -parse-as-library -target arm64-apple-macosx26.0 Sources/*.swift -o "$APP/Contents/MacOS/Lunar"
cp Info.plist "$APP/Contents/Info.plist"
ENGINE="$PWD/build/engine/app/Moonlight.app"
if [[ ! -d "$ENGINE/Contents/PlugIns/platforms" ]]; then
  print -u2 'Build the local engine first: zsh scripts/build-engine.sh'
  exit 1
fi
mkdir -p "$APP/Contents/Helpers"
ditto "$ENGINE" "$APP/Contents/Helpers/Lunar Stream.app"
cp "$APP/Contents/Resources/Lunar.icns" "$APP/Contents/Helpers/Lunar Stream.app/Contents/Resources/moonlight.icns"
python3 - "$APP/Contents/Helpers/Lunar Stream.app/Contents/Info.plist" <<'PY'
import plistlib, sys
path = sys.argv[1]
with open(path, 'rb') as file:
    info = plistlib.load(file)
info.update(CFBundleIdentifier='dev.balaji.lunar.stream', CFBundleName='Lunar Stream',
            CFBundleDisplayName='Lunar Stream', LSUIElement=True, LSMinimumSystemVersion='26.0',
            LSApplicationCategoryType='public.app-category.utilities',
            GCSupportsGameMode=False, LSSupportsGameMode=False,
            CFBundleShortVersionString='0.3.0', CFBundleVersion='3',
            CFBundleGetInfoString='Lunar remote desktop streaming',
            NSLocalNetworkUsageDescription='Lunar connects to computers on your local network for remote desktop streaming.')
with open(path, 'wb') as file:
    plistlib.dump(info, file)
PY
cp vendor/moonlight-qt-6.2.0/LICENSE "$APP/Contents/Resources/Moonlight-LICENSE.txt"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
print "Built $APP"
