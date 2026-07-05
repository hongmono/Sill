#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=Sill.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp .build/release/Sill "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

# Sparkle.framework 임베딩 (SPM 바이너리 아티팩트에서 복사)
SPARKLE_FW="$(find .build/artifacts -type d -name Sparkle.framework -path "*macos*" | head -1)"
cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Sill" 2>/dev/null || true

codesign --force --deep --sign - "$APP" # ad-hoc 서명: 화면 기록 권한(TCC)이 안정적으로 유지되게 함
echo "built: $APP"
