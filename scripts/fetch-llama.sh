#!/usr/bin/env bash
# Tải llama.xcframework (bản build sẵn, Metal shader đã nhúng) vào Vendor/.
# Ghim tag để C API không đổi bất ngờ.
set -euo pipefail

LLAMA_TAG="${LLAMA_TAG:-b12376}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Vendor"
STAMP="$DEST/.llama-tag"

if [[ -d "$DEST/llama.xcframework" && -f "$STAMP" && "$(cat "$STAMP")" == "$LLAMA_TAG" ]]; then
  echo "llama.xcframework $LLAMA_TAG đã có sẵn."
  exit 0
fi

URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_TAG}/llama-${LLAMA_TAG}-xcframework.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Đang tải $URL"
curl -fL --retry 3 -o "$TMP/llama.zip" "$URL"
unzip -q "$TMP/llama.zip" -d "$TMP/x"

rm -rf "$DEST/llama.xcframework"
mkdir -p "$DEST"
mv "$TMP/x/build-apple/llama.xcframework" "$DEST/llama.xcframework"
echo "$LLAMA_TAG" > "$STAMP"
echo "Xong: $DEST/llama.xcframework ($LLAMA_TAG)"
