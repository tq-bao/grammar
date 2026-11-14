# Tasks

## 1. Đối chiếu kết quả với câu gốc

- [x] 1.1 Thêm `CorrectionNormalizer.reconcile(original:corrected:)` vào GrammarKit. Hàm tách token cả hai câu, bỏ các token dấu câu ở cuối câu (`. , ; : ! ? …`), so khớp phần còn lại không phân biệt hoa thường, sau đó dựng lại câu sửa: từ khớp lấy đúng chữ của câu gốc, cuối câu gắn lại dấu cuối của câu gốc. Kiểm tra: unit test cho các scenario trong spec (giữ viết hoa, giữ dấu cuối, câu chỉ khác hoa thường hoặc dấu cuối thì trả về đúng câu gốc, câu có cả lỗi thật lẫn khác viết hoa).
- [x] 1.2 Dùng `reconcile` trong `CheckCoordinator` trước khi so diff và EditGuard, và trong `GrammarBench` trước khi chấm. Kiểm tra: unit test `CheckCoordinator` với engine giả trả về "Thanks, will check it tonight." cho câu "thanks, will check it tonight" thì state là `.ok`.

## 2. Prompt và golden set

- [x] 2.1 Thêm vào `GrammarPrompt` quy tắc không đổi viết hoa/viết thường và không đổi dấu câu cuối câu, đổi ví dụ mẫu cho khớp (bỏ ví dụ viết hoa "i"). Chuyển "i will call you after lunch." trong golden set sang nhóm câu đúng. Kiểm tra: chạy `GrammarBench` với model 7B, các chỉ số vẫn đạt ngưỡng (giữ nguyên câu đúng ≥ 95%, khớp đáp án ≥ 80%, p95 ≤ 1.5 giây), và cập nhật `docs/model-benchmark.md`.

## 3. Phát hành

- [x] 3.1 Chạy toàn bộ unit test, rồi chạy `scripts/install.sh` để build Release và cài vào `/Applications`. Kiểm tra: test pass, app được ký bằng "Grammar Local Signing" và đang chạy.
- [x] 3.2 Test tay: gõ "yesterday i go to the office" trong một app bất kỳ. Kiểm tra: panel chỉ gạch chân "go", và câu sửa là "yesterday i went to the office".
