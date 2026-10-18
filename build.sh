#!/bin/sh
# Builds Caliche CopyClip.app into ./build using SwiftPM, then ad-hoc signs it.
set -eu
cd "$(dirname "$0")"

swift build -c release
APP="build/Caliche CopyClip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/CalicheCopyClip" "$APP/Contents/MacOS/CalicheCopyClip"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Listo: $APP"
