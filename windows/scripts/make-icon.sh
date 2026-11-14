#!/bin/bash
# Sinh windows/src/Grammar.App/Resources/Grammar.ico từ icon của bản macOS
# (GrammarApp/Resources/Assets.xcassets/AppIcon.appiconset, vẽ bằng scripts/make-icon.swift).
# Chạy trên macOS (cần `sips`). File .ico được commit vào repo, chỉ cần chạy lại khi icon đổi.
set -euo pipefail
cd "$(dirname "$0")/../.."
SRC=GrammarApp/Resources/Assets.xcassets/AppIcon.appiconset
OUT=windows/src/Grammar.App/Resources/Grammar.ico
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for size in 16 24 32 48 64 256; do
  sips -s format png -z "$size" "$size" "$SRC/icon_512x512.png" --out "$TMP/$size.png" >/dev/null
done

# Gói các PNG vào một file ICO (Windows Vista trở lên đọc được PNG bên trong ICO).
python3 - "$TMP" "$OUT" <<'PY'
import struct, sys, os
tmp, out = sys.argv[1], sys.argv[2]
sizes = [16, 24, 32, 48, 64, 256]
images = [open(os.path.join(tmp, f"{s}.png"), "rb").read() for s in sizes]
header = struct.pack("<HHH", 0, 1, len(images))
offset = 6 + 16 * len(images)
entries = b""
for s, data in zip(sizes, images):
    dim = 0 if s >= 256 else s
    entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
    offset += len(data)
with open(out, "wb") as f:
    f.write(header + entries + b"".join(images))
print(f"Đã ghi {out} ({offset} byte)")
PY
