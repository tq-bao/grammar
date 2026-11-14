# Spec Delta

## MODIFIED Requirements

### Requirement: Đọc nội dung ô nhập liệu đang focus
Hệ thống SHALL đọc nội dung text của ô nhập liệu đang được focus trong app phía trước (frontmost), và cập nhật khi nội dung hoặc focus thay đổi, mà không cần người dùng thao tác thêm. Trên macOS, hệ thống đọc qua Accessibility API. Trên Windows, hệ thống đọc qua giao diện trợ năng UI Automation của Windows.

#### Scenario: Gõ trong app gốc của Apple
- **WHEN** người dùng gõ "She go to school yesterday." vào một ô trong TextEdit
- **THEN** hệ thống nhận được nội dung mới của ô đó trong vòng 1 giây sau lần gõ cuối

#### Scenario: Gõ trong app gốc của Windows
- **WHEN** trên Windows, người dùng gõ "She go to school yesterday." vào Notepad
- **THEN** hệ thống nhận được nội dung mới của ô đó trong vòng 1 giây sau lần gõ cuối

#### Scenario: Chuyển sang ô khác
- **WHEN** người dùng chuyển focus từ ô này sang ô nhập liệu khác (cùng app hoặc app khác)
- **THEN** hệ thống theo dõi ô mới và không còn dùng nội dung của ô cũ

#### Scenario: Gõ trong Chrome hoặc app Electron
- **WHEN** người dùng gõ trong ô nhập liệu của Chrome, Slack hoặc Teams
- **THEN** hệ thống cố gắng đọc nội dung ô đó, và nếu không đọc được thì không báo lỗi liên tục. Trên macOS người dùng dùng cách nhập dự phòng; trên Windows ô đó không được kiểm tra

### Requirement: Kiểm tra đoạn bôi đen bằng phím tắt
Trên macOS, hệ thống SHALL cung cấp phím tắt toàn cục (mặc định `⌃⌥G`) để lấy đoạn text đang bôi đen trong app phía trước và đưa vào kiểm tra. Clipboard của người dùng SHALL được khôi phục như trước khi bấm phím tắt. Trên Windows, hệ thống MUST NOT đăng ký phím tắt toàn cục nào và không có cách kiểm tra đoạn bôi đen.

#### Scenario: Bôi đen trong app không hỗ trợ đọc ô
- **WHEN** trên macOS, người dùng bôi đen "this are wrong" trong Teams và bấm `⌃⌥G`
- **THEN** panel hiển thị và kiểm tra "this are wrong"
- **AND** clipboard chứa đúng nội dung như trước khi bấm phím tắt

#### Scenario: Không có đoạn bôi đen
- **WHEN** trên macOS, người dùng bấm `⌃⌥G` mà không bôi đen gì
- **THEN** panel giữ nguyên nội dung cũ

#### Scenario: Không có phím tắt trên Windows
- **WHEN** trên Windows, người dùng bôi đen một đoạn rồi bấm Ctrl+Alt+G
- **THEN** app Grammar không phản ứng, clipboard và panel không thay đổi, và tổ hợp phím vẫn đến app đang gõ như bình thường

### Requirement: Yêu cầu quyền Accessibility
Trên macOS, hệ thống SHALL kiểm tra quyền Accessibility khi khởi động. Nếu chưa có quyền, hệ thống SHALL hiển thị hướng dẫn cấp quyền trên panel, cung cấp mục mở System Settings trên menu bar, và tự bắt đầu theo dõi khi quyền được cấp mà không cần khởi động lại app. Trên Windows không cần cấp quyền, nên hệ thống SHALL bắt đầu theo dõi ngay khi khởi động và không hiển thị hướng dẫn cấp quyền.

#### Scenario: Lần chạy đầu tiên
- **WHEN** trên macOS, app chạy lần đầu và chưa có quyền Accessibility
- **THEN** panel hiển thị hướng dẫn cấp quyền, và menu bar có mục "Cấp quyền Accessibility…" mở System Settings > Privacy & Security > Accessibility

#### Scenario: Người dùng cấp quyền
- **WHEN** trên macOS, người dùng bật quyền Accessibility cho app trong lúc app đang chạy
- **THEN** app bắt đầu theo dõi ô nhập liệu trong vòng vài giây và mục "Cấp quyền Accessibility…" biến mất khỏi menu bar

#### Scenario: Lần chạy đầu tiên trên Windows
- **WHEN** trên Windows, app chạy lần đầu
- **THEN** app bắt đầu theo dõi ô nhập liệu ngay, panel không hiển thị hướng dẫn cấp quyền, và menu khay không có mục cấp quyền

## ADDED Requirements

### Requirement: App chạy quyền quản trị trên Windows
Trên Windows, hệ thống chạy với quyền người dùng thường nên không đọc được ô nhập liệu của app đang chạy với quyền quản trị (Run as administrator). Khi ô đang focus thuộc app như vậy, hệ thống SHALL bỏ qua ô đó, giữ nguyên nội dung panel và MUST NOT báo lỗi liên tục.

#### Scenario: Gõ trong app chạy quyền quản trị
- **WHEN** trên Windows, người dùng gõ "this are wrong" trong một cửa sổ Notepad mở bằng "Run as administrator"
- **THEN** panel giữ nguyên nội dung cũ, không hiện thông báo lỗi, và app Grammar vẫn chạy bình thường

#### Scenario: Quay lại app thường
- **WHEN** sau đó người dùng chuyển sang gõ trong một cửa sổ Notepad thường
- **THEN** hệ thống đọc được ô đó như bình thường
