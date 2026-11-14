# Tasks

## 1. EditGuard

- [x] 1.1 `WordDiff`: trong mỗi nhóm thay đổi (nằm giữa hai token giữ nguyên), ghép từng từ bị xoá với một từ được thêm "gần giống" (Levenshtein ≤ 50% độ dài từ dài hơn, hoặc là tiền tố của nhau với tối thiểu 3 ký tự, không phân biệt hoa thường; dấu câu thay bằng dấu câu). Đếm `dissimilarRemovedCount` là số từ bị xoá không ghép được. Kiểm tra: unit test với "collect"/"collecting", "envidences"/"evidence", "dont"/"doesn't", "gonna"/"I will" (không ghép được).
- [x] 1.2 `EditGuard`: viết lại câu khi `dissimilarRemovedCount / originalTokenCount > 0.4`, hoặc khi `changeRatio > 0.8`, hoặc khi câu sửa có nhiều câu hơn câu gốc. Kiểm tra: `EditGuardTests` có thêm 2 scenario trong spec (được chấp nhận), các test cũ vẫn pass (câu viết lại hoàn toàn vẫn bị loại).

## 2. Golden set và phát hành

- [x] 2.1 Thêm "I'm collect more envidences" và "She dont has any monies" vào golden set. Chạy `GrammarBench` với model 7B. Kiểm tra: không câu nào bị EditGuard loại, các chỉ số vẫn đạt ngưỡng, cập nhật `docs/model-benchmark.md`.
- [x] 2.2 Chạy toàn bộ unit test rồi chạy `scripts/install.sh`. Kiểm tra: test pass, app mới đang chạy và được ký bằng "Grammar Local Signing".
- [x] 2.3 Test tay: gõ "I'm collect more envidences" trong một app bất kỳ. Kiểm tra: panel báo có lỗi và hiện câu sửa "I'm collecting more evidence".
