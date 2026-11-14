#!/usr/bin/env bash
# Build bản Release và cài Grammar vào /Applications.
#
#   scripts/install.sh
#
# - Chỉ giữ model mặc định (ModelLocator.defaultModelFileName) trong bản cài.
# - Ký bằng chứng chỉ "Grammar Local Signing" (tạo bằng scripts/create-signing-cert.sh) để quyền
#   Accessibility còn nguyên sau mỗi lần cài lại. Không có chứng chỉ thì ký ad-hoc và cảnh báo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY_NAME="${GRAMMAR_SIGNING_IDENTITY:-Grammar Local Signing}"
DEST="/Applications/Grammar.app"
cd "$ROOT"

DEFAULT_MODEL="$(sed -n 's/.*defaultModelFileName = "\(.*\)".*/\1/p' GrammarKit/Engine/ModelLocator.swift)"
if [[ -z "$DEFAULT_MODEL" || ! -f "GrammarApp/Resources/Models/$DEFAULT_MODEL" ]]; then
  echo "Thiếu model mặc định '$DEFAULT_MODEL' trong GrammarApp/Resources/Models/. Chạy scripts/download-model.sh trước." >&2
  exit 1
fi

echo "==> Build Release"
./scripts/fetch-llama.sh >/dev/null
xcodegen generate --quiet
xcodebuild -project GrammarApp.xcodeproj -scheme GrammarApp -configuration Release \
  -derivedDataPath build build -quiet
SRC="build/Build/Products/Release/Grammar.app"

echo "==> Tắt Grammar đang chạy"
osascript -e 'tell application id "local.grammar.GrammarApp" to quit' >/dev/null 2>&1 || true
pkill -x Grammar >/dev/null 2>&1 || true
sleep 1

echo "==> Copy vào $DEST"
rm -rf "$DEST"
cp -Rc "$SRC" "$DEST" 2>/dev/null || cp -R "$SRC" "$DEST"
find "$DEST/Contents/Resources/Models" -type f ! -name "$DEFAULT_MODEL" -delete

IDENTITY="$(security find-identity -p codesigning 2>/dev/null | awk -v n="\"$IDENTITY_NAME\"" 'index($0, n) {print $2; exit}')"
if [[ -n "$IDENTITY" ]]; then
  echo "==> Ký bằng \"$IDENTITY_NAME\""
else
  IDENTITY="-"
  echo "!!  Không thấy chứng chỉ \"$IDENTITY_NAME\", ký ad-hoc."
  echo "    Quyền Accessibility sẽ mất sau mỗi lần cài. Chạy scripts/create-signing-cert.sh để sửa."
fi
for framework in "$DEST"/Contents/Frameworks/*.framework; do
  codesign --force --sign "$IDENTITY" "$framework" >/dev/null 2>&1
done
codesign --force --sign "$IDENTITY" "$DEST" >/dev/null 2>&1
codesign --verify --deep --strict "$DEST"

echo "==> Mở Grammar"
open "$DEST"
echo "Xong: $DEST ($(du -sh "$DEST" | cut -f1)), model $DEFAULT_MODEL"
