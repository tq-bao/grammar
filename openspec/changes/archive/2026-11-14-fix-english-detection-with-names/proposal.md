# Proposal

## Why

Câu tiếng Anh ngắn có tên riêng tiếng Việt bị nhận nhầm là không phải tiếng Anh, nên app bỏ qua không kiểm tra. Ví dụ "Hi, my name is Bao" chỉ được bộ nhận diện ngôn ngữ chấm 0.34 cho tiếng Anh (0.30 cho tiếng Việt), thấp hơn nhiều so với ngưỡng 0.8 hiện tại. Người dùng là người Việt, thường xuyên nhắc tới tên người Việt trong tin nhắn tiếng Anh, nên lỗi này xảy ra thường xuyên.

## What Changes

- Bộ nhận diện ngôn ngữ được báo trước rằng người dùng chủ yếu gõ tiếng Anh và tiếng Việt (language hints: tiếng Anh 0.6, tiếng Việt 0.4).
- Một câu được coi là tiếng Anh khi khả năng là tiếng Anh từ 50% trở lên, tức tiếng Anh là khả năng cao nhất. Ngưỡng cũ là 80%.
- Đo trên các câu mẫu: câu tiếng Anh có tên Việt đạt ≥ 0.63. Câu tiếng Việt (có dấu hoặc không dấu) và các ngôn ngữ khác đều ≤ 0.29.

## Capabilities

### New Capabilities
<!-- Không có. -->

### Modified Capabilities
- `grammar-correction`: tiêu chí nhận diện câu tiếng Anh (ưu tiên tiếng Anh/tiếng Việt, ngưỡng 50%), thêm scenario câu tiếng Anh có tên riêng tiếng Việt.

## Impact

- **Code**: `GrammarKit/Pipeline/LanguageGate.swift` và test của nó.
- **Không đổi**: engine, prompt, panel. Số lần gọi model có thể tăng nhẹ ở những câu trước đây bị bỏ qua nhầm.
