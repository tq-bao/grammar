# Proposal

## Why

Khi dùng thực tế, người dùng thấy app báo lỗi cả những chỗ họ không quan tâm: viết hoa hay viết thường (ví dụ "i" so với "I", hay chữ đầu câu viết thường) và dấu câu ở cuối câu (thiếu dấu chấm, thừa dấu phẩy). Đặc biệt với tin nhắn chat, những "lỗi" này gây nhiễu và làm khó thấy lỗi ngữ pháp thật.

## What Changes

- Không còn coi khác biệt viết hoa/viết thường là lỗi. Câu sửa giữ nguyên cách viết hoa của người dùng ở mọi từ không bị sửa.
- Không còn coi dấu câu ở cuối câu là lỗi, gồm `. , ; : ! ? …`. Câu sửa giữ nguyên dấu cuối câu của người dùng, kể cả khi không có dấu nào.
- Dấu câu ở giữa câu vẫn được kiểm tra như trước.
- Ngoài việc dặn mô hình trong prompt, kết quả sửa được đối chiếu với câu gốc để trả lại đúng cách viết hoa và dấu cuối câu. Nhờ vậy hành vi trên luôn được đảm bảo, kể cả khi mô hình vẫn sửa những chỗ đó.

## Capabilities

### New Capabilities
<!-- Không có. -->

### Modified Capabilities
- `grammar-correction`: phạm vi sửa không còn gồm viết hoa/viết thường và dấu câu cuối câu. Câu chỉ khác ở những điểm đó được coi là không có lỗi.

## Impact

- **Code**:
  - `GrammarKit`: thêm bước đối chiếu kết quả với câu gốc, dùng trong `CheckCoordinator` và `GrammarBench`.
  - `GrammarPrompt`: thêm quy tắc mới và đổi ví dụ mẫu.
- **Golden set**: câu "i will call you after lunch." chuyển sang nhóm câu đúng.
- **Không đổi**: panel, cài đặt, cách lấy text, model.
