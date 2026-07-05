#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=ScreenshotStack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ScreenshotStack "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP" # ad-hoc 서명: 화면 기록 권한(TCC)이 안정적으로 유지되게 함
echo "built: $APP"
