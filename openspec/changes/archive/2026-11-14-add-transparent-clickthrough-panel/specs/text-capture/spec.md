# Spec Delta

## MODIFIED Requirements

### Requirement: Loại trừ nội dung nhạy cảm
Hệ thống MUST NOT đọc nội dung của ô mật khẩu (secure text field) và MUST NOT đọc nội dung của chính app này qua cơ chế theo dõi.

#### Scenario: Ô mật khẩu
- **WHEN** người dùng gõ vào một ô mật khẩu
- **THEN** hệ thống không đọc nội dung và panel không hiển thị gì từ ô đó

#### Scenario: Gõ trong panel của app
- **WHEN** người dùng click hoặc gõ phím khi con trỏ chuột đang nằm trên panel của app
- **THEN** panel không nhận nội dung (click xuyên qua) và cơ chế theo dõi không đọc gì từ chính app

#### Scenario: Cửa sổ của chính app
- **WHEN** cửa sổ Cài đặt của app đang được focus
- **THEN** cơ chế theo dõi ô focus bỏ qua và panel giữ nguyên nội dung cũ

### Requirement: Yêu cầu quyền Accessibility
Hệ thống SHALL kiểm tra quyền Accessibility khi khởi động. Nếu chưa có quyền, hệ thống SHALL hiển thị hướng dẫn cấp quyền trên panel, cung cấp mục mở System Settings trên menu bar, và tự bắt đầu theo dõi khi quyền được cấp mà không cần khởi động lại app.

#### Scenario: Lần chạy đầu tiên
- **WHEN** app chạy lần đầu và chưa có quyền Accessibility
- **THEN** panel hiển thị hướng dẫn cấp quyền, và menu bar có mục "Cấp quyền Accessibility…" mở System Settings > Privacy & Security > Accessibility

#### Scenario: Người dùng cấp quyền
- **WHEN** người dùng bật quyền Accessibility cho app trong lúc app đang chạy
- **THEN** app bắt đầu theo dõi ô nhập liệu trong vòng vài giây và mục "Cấp quyền Accessibility…" biến mất khỏi menu bar

## REMOVED Requirements

### Requirement: Nhập tay trực tiếp vào panel
**Reason**: Panel nay luôn cho click xuyên qua nên không nhận chuột và bàn phím, không thể gõ hay dán vào được.
**Migration**: Bôi đen đoạn cần kiểm tra ở bất kỳ app nào rồi bấm `⌃⌥G` (requirement "Kiểm tra đoạn bôi đen bằng phím tắt"). Muốn kiểm tra một câu tự soạn thì gõ vào app bất kỳ, ví dụ TextEdit hay Notes.
