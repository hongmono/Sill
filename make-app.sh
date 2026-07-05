#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=Sill.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp .build/release/Sill "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources" && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Sparkle.framework 임베딩 (SPM 바이너리 아티팩트에서 복사)
SPARKLE_FW="$(find .build/artifacts -type d -name Sparkle.framework -path "*macos*" | head -1)"
cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Sill" 2>/dev/null || true

# Developer ID로 서명해야 재빌드해도 화면 기록 권한(TCC)이 유지된다.
# ad-hoc(-)은 빌드마다 신원이 바뀌어 권한이 매번 초기화됨. 인증서 없으면 ad-hoc 폴백.
# 릴리스(CI)와 같은 개인 인증서 우선 — 신원이 다르면 빌드 전환 시 권한을 또 묻는다
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
  | grep -m1 "THG2GV26Z9" || security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
codesign --force --deep --sign "${IDENTITY:--}" "$APP"
echo "built: $APP (signed: ${IDENTITY:-ad-hoc})"
