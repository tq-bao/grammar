# text-capture Specification

## Purpose
Lấy nội dung tiếng Anh mà người dùng đang gõ trong các app khác trên macOS để đưa vào kiểm tra ngữ pháp, đồng thời tôn trọng quyền riêng tư (không đọc ô mật khẩu, không gửi ra ngoài).

## Requirements

### Requirement: Đọc nội dung ô nhập liệu đang focus
Hệ thống SHALL đọc nội dung text của ô nhập liệu đang được focus trong app phía trước (frontmost), và cập nhật khi nội dung hoặc focus thay đổi, mà không cần người dùng thao tác thêm.

#### Scenario: Gõ trong app gốc của Apple
- **WHEN** người dùng gõ "She go to school yesterday." vào một ô trong TextEdit
- **THEN** hệ thống nhận được nội dung mới của ô đó trong vòng 1 giây sau lần gõ cuối

#### Scenario: Chuyển sang ô khác
- **WHEN** người dùng chuyển focus từ ô này sang ô nhập liệu khác (cùng app hoặc app khác)
- **THEN** hệ thống theo dõi ô mới và không còn dùng nội dung của ô cũ

#### Scenario: Gõ trong Chrome hoặc app Electron
- **WHEN** người dùng gõ trong ô nhập liệu của Chrome, Slack hoặc Teams
- **THEN** hệ thống cố gắng đọc nội dung ô đó, và nếu không đọc được thì để người dùng dùng cách nhập dự phòng (không báo lỗi liên tục)

### Requirement: Tách câu đang chứa con trỏ
Hệ thống SHALL chỉ lấy câu đang chứa con trỏ trong ô nhập liệu để kiểm tra. Nếu không xác định được vị trí con trỏ, hệ thống SHALL lấy câu cuối cùng trong ô.

#### Scenario: Ô có nhiều câu
- **WHEN** ô chứa "I like tea. He have two cats. We are fine." và con trỏ nằm trong câu thứ hai
- **THEN** câu được lấy ra là "He have two cats."

#### Scenario: Không có thông tin con trỏ
- **WHEN** app nguồn không cung cấp vị trí con trỏ
- **THEN** hệ thống lấy câu cuối cùng trong ô

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

### Requirement: Nội dung chỉ xử lý trên máy
Hệ thống MUST NOT gửi nội dung đọc được ra mạng và MUST NOT lưu nội dung đó xuống đĩa.

#### Scenario: Không có kết nối mạng
- **WHEN** máy không có mạng
- **THEN** toàn bộ việc lấy text và kiểm tra ngữ pháp vẫn hoạt động bình thường

### Requirement: Kiểm tra đoạn bôi đen bằng phím tắt
Hệ thống SHALL cung cấp phím tắt toàn cục (mặc định `⌃⌥G`) để lấy đoạn text đang bôi đen trong app phía trước và đưa vào kiểm tra. Clipboard của người dùng SHALL được khôi phục như trước khi bấm phím tắt.

#### Scenario: Bôi đen trong app không hỗ trợ đọc ô
- **WHEN** người dùng bôi đen "this are wrong" trong Teams và bấm `⌃⌥G`
- **THEN** panel hiển thị và kiểm tra "this are wrong"
- **AND** clipboard chứa đúng nội dung như trước khi bấm phím tắt

#### Scenario: Không có đoạn bôi đen
- **WHEN** người dùng bấm `⌃⌥G` mà không bôi đen gì
- **THEN** panel giữ nguyên nội dung cũ

### Requirement: Yêu cầu quyền Accessibility
Hệ thống SHALL kiểm tra quyền Accessibility khi khởi động. Nếu chưa có quyền, hệ thống SHALL hiển thị hướng dẫn cấp quyền trên panel, cung cấp mục mở System Settings trên menu bar, và tự bắt đầu theo dõi khi quyền được cấp mà không cần khởi động lại app.

#### Scenario: Lần chạy đầu tiên
- **WHEN** app chạy lần đầu và chưa có quyền Accessibility
- **THEN** panel hiển thị hướng dẫn cấp quyền, và menu bar có mục "Cấp quyền Accessibility…" mở System Settings > Privacy & Security > Accessibility

#### Scenario: Người dùng cấp quyền
- **WHEN** người dùng bật quyền Accessibility cho app trong lúc app đang chạy
- **THEN** app bắt đầu theo dõi ô nhập liệu trong vòng vài giây và mục "Cấp quyền Accessibility…" biến mất khỏi menu bar
