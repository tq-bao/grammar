#!/usr/bin/env bash
# Tải một file model GGUF từ Hugging Face vào GrammarApp/Resources/Models/.
#
#   scripts/download-model.sh <hf-repo-id> <file.gguf>
#   scripts/download-model.sh bartowski/Qwen2.5-3B-Instruct-GGUF Qwen2.5-3B-Instruct-Q4_K_M.gguf
#
# Có thể tải tiếp khi bị ngắt (curl -C -). Model được copy vào app bundle lúc build.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Cách dùng: $0 <hf-repo-id> <file.gguf>" >&2
  exit 64
fi

REPO="$1"
FILE="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$ROOT/GrammarApp/Resources/Models"
DEST="$DEST_DIR/$FILE"
URL="https://huggingface.co/${REPO}/resolve/main/${FILE}?download=true"

mkdir -p "$DEST_DIR"

if [[ -f "$DEST" && ! -f "$DEST.part" ]]; then
  echo "Đã có: $DEST"
else
  echo "Đang tải $REPO/$FILE"
  curl -fL --retry 5 -C - -o "$DEST.part" "$URL"
  mv "$DEST.part" "$DEST"
fi

MAGIC="$(head -c 4 "$DEST")"
if [[ "$MAGIC" != "GGUF" ]]; then
  echo "Lỗi: $DEST không phải file GGUF hợp lệ." >&2
  exit 1
fi
echo "OK: $DEST ($(du -h "$DEST" | cut -f1))"
