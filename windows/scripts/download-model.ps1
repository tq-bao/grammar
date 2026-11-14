# Tải model GGUF từ Hugging Face vào thư mục Models\ cạnh Grammar.exe. Bản Windows của scripts/download-model.sh.
#
#   powershell -ExecutionPolicy Bypass -File download-model.ps1
#   powershell -ExecutionPolicy Bypass -File download-model.ps1 -Repo bartowski/Qwen2.5-3B-Instruct-GGUF -File Qwen2.5-3B-Instruct-Q4_K_M.gguf
#
# Tải tiếp được khi bị ngắt (chạy lại lệnh). Cần curl.exe (có sẵn từ Windows 10 1803).
param(
    [string]$Repo = "bartowski/Qwen2.5-7B-Instruct-GGUF",
    [string]$File = "Qwen2.5-7B-Instruct-Q4_K_M.gguf"
)
$ErrorActionPreference = "Stop"

$models = Join-Path $PSScriptRoot "Models"
New-Item -ItemType Directory -Force -Path $models | Out-Null
$target = Join-Path $models $File
$url = "https://huggingface.co/$Repo/resolve/main/$File"

Write-Host "Tải $url"
Write-Host "  -> $target"
& curl.exe -L --fail --retry 3 -C - -o $target $url
if ($LASTEXITCODE -ne 0) { throw "Tải thất bại (curl mã $LASTEXITCODE). Chạy lại lệnh để tải tiếp." }

# File GGUF hợp lệ bắt đầu bằng 4 byte "GGUF".
$stream = [System.IO.File]::OpenRead($target)
try {
    $magic = New-Object byte[] 4
    [void]$stream.Read($magic, 0, 4)
} finally {
    $stream.Dispose()
}
if ([System.Text.Encoding]::ASCII.GetString($magic) -ne "GGUF") {
    throw "File tải về không phải GGUF: $target"
}
$size = [math]::Round((Get-Item $target).Length / 1GB, 2)
Write-Host "Xong: $File ($size GB). Mở lại Grammar để dùng model này."
