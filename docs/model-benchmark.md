# Benchmark model sửa ngữ pháp

Đo ngày 2026-11-14 trên Apple M4 Pro (48 GB), llama.cpp `b12376`, model GGUF Q4_K_M, sampler greedy (temperature 0).
Golden set: [GrammarAppTests/Fixtures/golden.json](../GrammarAppTests/Fixtures/golden.json), gồm 33 câu sai có đáp án và 21 câu đúng.

Kể từ change `ignore-case-and-final-punctuation`, khác biệt viết hoa/viết thường và dấu câu cuối câu **không tính là lỗi**. Kết quả của model đi qua `CorrectionNormalizer.reconcile` trước khi chấm, giống trong app.

Chạy lại:

```bash
xcodebuild -project GrammarApp.xcodeproj -scheme GrammarBench -configuration Release -derivedDataPath build build
./build/Build/Products/Release/GrammarBench \
  --model GrammarApp/Resources/Models/Qwen2.5-3B-Instruct-Q4_K_M.gguf \
  --model GrammarApp/Resources/Models/Qwen2.5-7B-Instruct-Q4_K_M.gguf
```

## Ngưỡng (design.md §5)

- Giữ nguyên câu đúng: ≥ 95%
- Khớp đáp án: ≥ 80%
- Độ trễ p95: ≤ 1.5 giây

## Kết quả cuối cùng (prompt hiện tại, có cache prompt cố định; dòng 3B đo ở lần 3)

| Model | Giữ nguyên câu đúng | Khớp đáp án | EditGuard loại | p50 | p95 | Nạp + warm-up |
|---|---|---|---|---|---|---|
| Qwen2.5-3B-Instruct-Q4_K_M | 95% | 72% ✗ | 0% | 161 ms | 298 ms | 1.7 s |
| **Qwen2.5-7B-Instruct-Q4_K_M** | **100%** | **88%** | 0% | 279 ms | 424 ms | 1.9 s |

**Model mặc định: Qwen2.5-7B-Instruct-Q4_K_M** (`ModelLocator.defaultModelFileName`). Đây là model nhỏ nhất đạt cả ba ngưỡng. Bản 3B nhanh hơn nhưng bỏ sót nhiều lỗi mạo từ, giới từ và danh từ không đếm được.

## Quá trình chỉnh

| Lần | Thay đổi | 3B: giữ / khớp / p95 | 7B: giữ / khớp / p95 |
|---|---|---|---|
| 1 | Prompt ban đầu (4 ví dụ) | 90% / 78% / 488 ms | 90% / 81% / 1110 ms |
| 2 | Thêm quy tắc: giữ từ viết tắt kiểu chat, không tự thêm dấu chấm, dấu phẩy, viết hoa; liệt kê các loại lỗi cần sửa. Đổi ví dụ để không trùng câu nào trong golden set | 95% / 72% / 694 ms | 100% / 84% / 1659 ms ✗ |
| 3 | Giữ KV cache của phần prompt cố định (system + ví dụ) giữa các lần gọi. Kết quả sửa không đổi, chỉ nhanh hơn | 95% / 72% / 298 ms | 100% / 84% / 453 ms |
| 4 | Bỏ qua viết hoa/viết thường và dấu câu cuối câu (prompt + đối chiếu với câu gốc). Câu "i will call you after lunch." chuyển sang nhóm câu đúng. Chỉ đo lại 7B | – | 100% / 87% / 485 ms |
| 5 | EditGuard không tính sửa dạng từ/chính tả là viết lại câu (change `fix-rewrite-guard-word-forms`). Thêm 2 câu ngắn nhiều lỗi: "I'm collect more envidences", "She dont has any monies". Trước khi sửa, cả 2 đều bị EditGuard loại | – | 100% / 88% / 424 ms |

## Lỗi còn lại của 7B

| Câu gốc | Kết quả model | Đáp án |
|---|---|---|
| I have saw that movie last week. | I have seen that movie last week. | I saw that movie last week. |
| He has went home already. | He has already gone home. (sửa đúng, nhưng đổi trật tự từ) | He has gone home already. |
| There are many informations in the document. | (giữ nguyên) | There is a lot of information in the document. |
| I am good in math. | (giữ nguyên) | I am good at math. |

Không có kết quả nào bị EditGuard loại, tức là model không viết lại câu trong bộ test này.

## Dịch sang tiếng Việt (change `add-vietnamese-translation`)

Đo ngày 2026-11-14 trên cùng máy Apple M4 Pro, model Qwen2.5-7B-Instruct-Q4_K_M. Bộ câu mẫu (`translationSamples` trong `GrammarBench/main.swift`) gồm 15 câu: câu thường, câu viết tắt kiểu chat, câu có tên riêng/thuật ngữ, câu hỏi, câu yêu cầu, và một câu dài khoảng 40 từ. Mỗi lần dịch được xen kẽ với một lần sửa ngữ pháp, để kiểm tra rằng context dịch riêng không làm mất KV cache của prompt sửa.

```bash
./build/Build/Products/Release/GrammarBench \
  --model GrammarApp/Resources/Models/Qwen2.5-7B-Instruct-Q4_K_M.gguf --translate
```

| | p50 | p95 |
|---|---|---|
| Dịch | 353 ms | 1393 ms |
| Sửa ngữ pháp ngay sau mỗi lần dịch | 282 ms | 307 ms |

- p95 của bước dịch đến từ hai lần chạy:
  - **Lần dịch đầu tiên** (1.4 s), gồm tạo context dịch, quét vocab để cấm token CJK, và prefill prompt cố định. Từ lần thứ hai, prompt cố định đã nằm trong KV cache.
  - **Câu dài khoảng 40 từ** (1.6 s).
- Bước sửa không chậm đi khi xen kẽ với dịch. Golden set vẫn cho 100% / 88%, giống trước khi có tính năng Dịch.

### Chất lượng

Ban đầu, 1/15 câu bị lẫn tiếng Trung: "Tôi giỏi môn toán nhưng cần练习一下翻译技能…". Thêm quy tắc vào prompt không sửa được. Sau khi cấm các token chứa ký tự Trung/Nhật/Hàn trong sampler dịch (design §5b), câu này dịch đúng, và không còn bản dịch nào có ký tự CJK.

Lỗi còn lại (3/15). Vì vậy section trên panel có tiêu đề "Bản dịch (tham khảo)":

| Câu gốc | Bản dịch | Lỗi |
|---|---|---|
| What time does the meeting start tomorrow? | Cuộc họp bắt đầu lúc mấy giờTomorrow? | Dính chữ tiếng Anh, thiếu "ngày mai" |
| Please review my pull request before Friday. | Vui lòng review pull request của tôi trước khi thứ Năm. | Sai thứ (Friday là thứ Sáu) |
| There is a lot of information in the document. | Đocument chứa nhiều thông tin. | Méo chữ "tài liệu" |

Các câu hỏi và yêu cầu ("Can you send me the file?", "Write a poem about the sea.") đều được dịch, không bị trả lời hay làm theo.

## Bản Windows (LLamaSharp)

Bản Windows (`windows/`) chạy llama.cpp qua LLamaSharp 0.30.0, không dùng tag `b12376` như bản macOS. Golden set và prompt dùng chung với bản macOS, nên mục này kiểm tra việc đổi runtime có làm đổi kết quả hay không.

Đo ngày 2026-11-14 trên cùng máy Apple M4 Pro (48 GB), bằng `Grammar.Bench` (backend Metal của LLamaSharp; trên Windows là Vulkan hoặc CPU):

```bash
cd windows && dotnet build src/Grammar.Bench -c Release
dotnet src/Grammar.Bench/bin/Release/net10.0/Grammar.Bench.dll \
  --model ../GrammarApp/Resources/Models/Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  --model ../GrammarApp/Resources/Models/Qwen2.5-3B-Instruct-Q4_K_M.gguf [--cpu]
```

| Model | Phần cứng | Giữ nguyên câu đúng | Khớp đáp án | EditGuard loại | p50 | p95 | Nạp + warm-up |
|---|---|---|---|---|---|---|---|
| **Qwen2.5-7B-Instruct-Q4_K_M** | GPU (Metal, 29 layer) | **100%** | **88%** | 0% | 274 ms | 419 ms | 3.4 s |
| Qwen2.5-3B-Instruct-Q4_K_M | GPU (Metal, 37 layer) | 100% | 76% ✗ | 0% | 141 ms | 217 ms | 1.5 s |
| **Qwen2.5-7B-Instruct-Q4_K_M** | CPU (`--cpu`) | **100%** | **88%** | 0% | 456 ms | 731 ms | 7.9 s |
| Qwen2.5-3B-Instruct-Q4_K_M | CPU (`--cpu`) | 100% | 82% | 0% | 220 ms | 355 ms | 3.7 s |

- Model 7B cho đúng kết quả của bản macOS (100% / 88%), và sai đúng 4 câu ở mục "Lỗi còn lại của 7B". Đổi runtime không làm đổi chất lượng.
- 3B cho kết quả hơi khác nhau giữa GPU và CPU, do sai số tính toán của từng backend làm đổi token được chọn ở vài câu.
- Số đo CPU ở đây là CPU M4 Pro. CPU laptop Windows phổ thông có thể chậm hơn vài lần. Cần chạy lại `Grammar.Bench.exe` (nằm cạnh `Grammar.exe`) trên máy Windows thật và ghi vào bảng dưới.

### Máy Windows thật

| Ngày | CPU / GPU / RAM | Model | Phần cứng | Giữ nguyên | Khớp | p50 | p95 | Nạp + warm-up |
|---|---|---|---|---|---|---|---|---|
| (chưa đo) | | | | | | | | |
