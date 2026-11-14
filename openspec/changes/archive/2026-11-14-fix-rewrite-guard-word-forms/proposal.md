# Proposal

## Why

Câu tiếng Anh ngắn có từ 2 lỗi trở lên bị báo "Không chắc chắn" dù mô hình sửa đúng. Ví dụ "I'm collect more envidences" được sửa thành "I'm collecting more evidence", nhưng 2/4 từ thay đổi (50%) vượt ngưỡng 40%, nên EditGuard coi đó là viết lại câu. Ngưỡng này đang tính cả những từ chỉ được sửa dạng hoặc chính tả, mà đó chính là việc sửa ngữ pháp người dùng mong đợi.

## What Changes

- EditGuard chỉ tính những từ bị **thay bằng một từ khác hẳn**.
- Từ được sửa dạng hoặc chính tả (collect → collecting, envidences → evidence, dont → doesn't, has → have) không bị tính là viết lại.
- Hai từ được coi là cùng một từ khi khoảng cách Levenshtein ≤ 50% độ dài từ dài hơn, hoặc từ này là tiền tố của từ kia (tối thiểu 3 ký tự). Thay dấu câu bằng dấu câu khác không bị tính.
- Ngưỡng 40% giữ nguyên, áp dụng cho số từ bị thay bằng từ khác hẳn. Thêm mức chặn phụ: tổng số từ thay đổi (gồm cả sửa dạng từ) vượt 80% thì vẫn coi là viết lại câu.
- Golden set thêm câu ngắn có nhiều lỗi để phát hiện lỗi này nếu tái diễn.

## Capabilities

### New Capabilities
<!-- Không có. -->

### Modified Capabilities
- `grammar-correction`: tiêu chí "viết lại câu" chỉ tính từ bị thay bằng từ khác hẳn, không tính sửa dạng từ hay chính tả.

## Impact

- **Code**: `GrammarKit/Diff/WordDiff.swift` (đếm từ bị thay bằng từ khác hẳn), `GrammarKit/Diff/EditGuard.swift`, test tương ứng, `GrammarAppTests/Fixtures/golden.json`.
- **Không đổi**: engine, prompt, panel, cách gạch chân.
