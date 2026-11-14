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
