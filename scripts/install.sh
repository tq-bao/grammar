#!/usr/bin/env bash
# Build bản Release và cài Grammar vào /Applications.
#
#   scripts/install.sh
#
# - App không chứa model. Nếu đã có model mặc định trong GrammarApp/Resources/Models/ (tải bằng
#   scripts/download-model.sh) thì copy sang ~/Library/Application Support/Grammar/Models/ để app
#   không phải tải lại. Không có thì app hỏi tải model ở lần mở đầu tiên.
# - Ký bằng chứng chỉ "Grammar Local Signing" (xem scripts/lib/sign.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Grammar.app"
MODELS_DIR="$HOME/Library/Application Support/Grammar/Models"
cd "$ROOT"
source scripts/lib/sign.sh

DEFAULT_MODEL="$(sed -n 's/.*defaultModelFileName = "\(.*\)".*/\1/p' GrammarKit/Engine/ModelLocator.swift)"

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

LOCAL_MODEL="GrammarApp/Resources/Models/$DEFAULT_MODEL"
if [[ -f "$MODELS_DIR/$DEFAULT_MODEL" ]]; then
  echo "==> Đã có model ở $MODELS_DIR"
elif [[ -f "$LOCAL_MODEL" ]]; then
  echo "==> Copy model $DEFAULT_MODEL sang $MODELS_DIR"
  mkdir -p "$MODELS_DIR"
  # cp -c: clone APFS, gần như tức thì và không tốn thêm chỗ.
  cp -c "$LOCAL_MODEL" "$MODELS_DIR/$DEFAULT_MODEL" 2>/dev/null || cp "$LOCAL_MODEL" "$MODELS_DIR/$DEFAULT_MODEL"
else
  echo "==> Chưa có model, app sẽ hỏi tải ở lần mở đầu tiên"
fi

IDENTITY="$(grammar_signing_identity)"
grammar_sign_app "$DEST" "$IDENTITY"

echo "==> Mở Grammar"
open "$DEST"
echo "Xong: $DEST ($(du -sh "$DEST" | cut -f1))"
