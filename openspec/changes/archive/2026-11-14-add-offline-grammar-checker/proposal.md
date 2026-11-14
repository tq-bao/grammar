# Proposal

## Why

Khi viết tiếng Anh trong Slack, Teams, trình duyệt hay các app của Apple, người dùng muốn biết ngay câu mình đang gõ có sai ngữ pháp không. Họ cần biết sai ở đâu và câu đúng là gì, nhưng không muốn bị diễn đạt lại câu. Các công cụ hiện có hoặc cần internet, gửi nội dung ra ngoài, hoặc hay viết lại cả câu. Vì vậy cần một app macOS chạy hoàn toàn offline, chỉ sửa ngữ pháp.

## What Changes

- Thêm một app macOS mới (menu bar app, SwiftUI, Swift 6, macOS 26+). Dự án hiện chưa có code.
- App tự theo dõi ô nhập liệu đang được focus ở các app khác qua Accessibility API và lấy câu đang chứa con trỏ.
- Chỉ xử lý câu tiếng Anh, nhận diện ngôn ngữ ngay trên máy. Bỏ qua ô mật khẩu và chính app này.
- Kiểm tra ngữ pháp bằng một LLM chạy offline trên máy (llama.cpp + model GGUF 4-bit tải kèm app). Không gọi mạng.
- Chỉ sửa ngữ pháp, chính tả, dấu câu. Không đổi ý, giọng văn hay cách dùng từ. Câu đúng được giữ nguyên. Kết quả sửa quá nhiều sẽ bị loại.
- Hiển thị trong một panel nổi gồm 2 phần. Phần trên là câu gốc, gạch chân đỏ dưới cụm sai. Phần dưới là câu đã sửa. App không ghi ngược vào app người dùng đang gõ.
- Dự phòng cho app không đọc được text: phím tắt toàn cục để kiểm tra đoạn đang bôi đen. Người dùng cũng có thể gõ hoặc dán trực tiếp vào panel.
- Có script tải model về để đóng gói. File model không được đưa vào git.

## Capabilities

### New Capabilities
- `text-capture`: Lấy nội dung người dùng đang gõ ở app khác. Gồm đọc ô đang focus, tách câu chứa con trỏ, loại trừ vì riêng tư (ô mật khẩu, chính app) và các cách nhập dự phòng (phím tắt cho đoạn bôi đen, nhập tay).
- `grammar-correction`: Nhận diện câu tiếng Anh và sửa ngữ pháp offline bằng LLM trên máy, với ràng buộc chỉ sửa ngữ pháp. Gồm cả chống sửa quá tay, debounce và cache.
- `checker-window`: Panel 2 phần hiển thị câu gốc (gạch chân đỏ cụm sai) và câu đã sửa, cùng menu bar điều khiển và hướng dẫn cấp quyền.

### Modified Capabilities
<!-- Không có, dự án chưa có spec nào. -->

## Impact

- **Code mới**: framework `GrammarKit/` (Diff, Pipeline, Engine), app `GrammarApp/` (App, Capture, UI), target test `GrammarAppTests/` và tool `GrammarBench/`.
- **Dependency**: `llama.xcframework` bản build sẵn của llama.cpp (ghim tag, tải bằng `scripts/fetch-llama.sh` vào `Vendor/`, git-ignored). Framework hệ thống: ApplicationServices (Accessibility), NaturalLanguage, AppKit/SwiftUI.
- **Model**: một file GGUF Q4_K_M khoảng 2–4.7 GB (Qwen2.5 3B hoặc 7B Instruct, chọn sau khi benchmark), tải bằng `scripts/download-model.sh` vào `Resources/Models/` (git-ignored).
- **Quyền hệ thống**: cần quyền Accessibility. App không sandbox nên không phát hành qua Mac App Store. Trên máy quản lý bằng MDM, quyền này có thể bị chặn.
- **Riêng tư**: mọi nội dung chỉ xử lý trong bộ nhớ trên máy, không lưu và không gửi ra ngoài.
