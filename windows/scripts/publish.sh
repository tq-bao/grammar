#!/bin/bash
# Đóng gói bản Windows thành dist/Grammar-win-x64.zip. Chạy được trên macOS hoặc Linux (cần .NET 10 SDK).
#
#   windows/scripts/publish.sh
#
# Kết quả: thư mục dist/Grammar (giải nén ra là chạy, không cần cài .NET):
#   Grammar.exe            app
#   Grammar.Bench.exe      đo độ chính xác và độ trễ trên golden set
#   Grammar.Probe.exe      chẩn đoán app nào đọc được qua UI Automation
#   download-model.ps1     tải model vào Models\
#   Models\                đặt file .gguf vào đây (không kèm trong zip vì quá lớn)
#   runtimes\win-x64\      llama.cpp: noavx, avx, avx2, avx512 (CPU) và vulkan (GPU)
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=dist/Grammar
ZIP=dist/Grammar-win-x64.zip
COMMON=(-c Release -r win-x64 --self-contained -p:PublishSingleFile=false -p:DebugType=none -p:DebugSymbols=false)

rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT"

# Ba chương trình publish chung một thư mục để dùng chung runtime .NET và thư viện llama.cpp.
dotnet publish src/Grammar.App "${COMMON[@]}" -o "$OUT"
dotnet publish src/Grammar.Bench "${COMMON[@]}" -o "$OUT"
dotnet publish src/Grammar.Probe "${COMMON[@]}" -o "$OUT"

# LLamaSharp chép thư viện native của mọi nền tảng; chỉ giữ win-x64.
find "$OUT/runtimes" -mindepth 1 -maxdepth 1 -type d ! -name win-x64 -exec rm -rf {} +

for variant in noavx avx avx2 avx512 vulkan; do
  if [ ! -f "$OUT/runtimes/win-x64/native/$variant/llama.dll" ]; then
    echo "Thiếu runtimes/win-x64/native/$variant/llama.dll" >&2
    exit 1
  fi
done

# Golden set dùng chung với bản macOS, để Grammar.Bench chạy được trên máy Windows.
cp ../GrammarAppTests/Fixtures/golden.json "$OUT/golden.json"
cp scripts/download-model.ps1 "$OUT/download-model.ps1"
cp README.md "$OUT/README.md"
mkdir -p "$OUT/Models"
cat > "$OUT/Models/README.txt" <<'TXT'
Đặt file model GGUF vào thư mục này, ví dụ Qwen2.5-7B-Instruct-Q4_K_M.gguf (mặc định, ~4.7 GB).
Tải bằng: powershell -ExecutionPolicy Bypass -File ..\download-model.ps1
Hoặc copy file .gguf có sẵn từ máy khác (GrammarApp/Resources/Models/ của bản macOS).
Có nhiều file .gguf thì chọn model trong Cài đặt của Grammar.
TXT

(cd dist && zip -qr "$(basename "$ZIP")" Grammar)
echo "Đã tạo $ZIP ($(du -h "$ZIP" | cut -f1))"
