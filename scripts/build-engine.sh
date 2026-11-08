#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
SOURCE="$PWD/vendor/moonlight-qt-6.2.0"
BUILD="$PWD/build/engine"
QT=/opt/homebrew/opt/qtbase/bin
if [[ ! -d "$SOURCE/libs/mac" ]]; then
  (cd "$SOURCE" && python3 setup-deps.py)
fi
mkdir -p "$BUILD"
cd "$BUILD"
"$QT/qmake" "$SOURCE/moonlight-qt.pro" 'QMAKE_APPLE_DEVICE_ARCHS=arm64' 'QMAKE_MACOSX_DEPLOYMENT_TARGET=26.0' 'CONFIG+=release'
make -j6 release > "$BUILD/build.log" 2>&1
"$QT/macdeployqt" "$BUILD/app/Moonlight.app" -qmldir="$SOURCE/app/gui" -appstore-compliant -no-codesign
