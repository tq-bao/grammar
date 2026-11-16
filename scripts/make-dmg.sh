#!/usr/bin/env bash
# Build bản Release, ký, rồi đóng gói thành dist/Grammar-<version>.dmg để chia sẻ.
#
#   scripts/make-dmg.sh
#
# DMG không chứa model: app tải model (~4.7 GB) ở lần mở đầu tiên.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source scripts/lib/sign.sh

echo "==> Build Release"
./scripts/fetch-llama.sh >/dev/null
xcodegen generate --quiet
xcodebuild -project GrammarApp.xcodeproj -scheme GrammarApp -configuration Release \
  -derivedDataPath build build -quiet
SRC="build/Build/Products/Release/Grammar.app"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SRC/Contents/Info.plist")"
OUT="dist/Grammar-$VERSION.dmg"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "==> Chuẩn bị nội dung DMG"
cp -R "$SRC" "$STAGING/Grammar.app"
if find "$STAGING/Grammar.app" -name '*.gguf' | grep -q .; then
  echo "!!  Bundle có chứa file .gguf, DMG sẽ rất nặng. Kiểm tra lại project.yml." >&2
fi
ln -s /Applications "$STAGING/Applications"

IDENTITY="$(grammar_signing_identity)"
grammar_sign_app "$STAGING/Grammar.app" "$IDENTITY"

echo "==> Tạo $OUT"
mkdir -p dist
hdiutil create -volname Grammar -srcfolder "$STAGING" -format UDZO -ov "$OUT" >/dev/null
echo "Xong: $OUT ($(du -h "$OUT" | cut -f1))"
