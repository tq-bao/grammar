## MODIFIED Requirements

### Requirement: Sửa ngữ pháp offline
Hệ thống SHALL sửa ngữ pháp bằng mô hình ngôn ngữ chạy trên máy, và MUST hoạt động khi không có mạng, sau khi mô hình đã có trên máy. Trên macOS, mô hình không đóng gói kèm app mà được tải về một lần, sau khi người dùng đồng ý, và lưu trong thư mục dữ liệu của người dùng (xem `model-download`). Trên Windows, mô hình là file đặt trong thư mục `Models` cạnh file chạy của app.

#### Scenario: Không có mạng
- **WHEN** mô hình đã có trên máy, máy không có kết nối mạng, và người dùng gõ "They was happy."
- **THEN** hệ thống vẫn trả về "They were happy."

#### Scenario: Model chưa sẵn sàng
- **WHEN** không tìm thấy file model hoặc model không nạp được
- **THEN** panel hiển thị thông báo lỗi rõ ràng, còn app vẫn chạy và không crash

#### Scenario: Chưa tải model trên macOS
- **WHEN** trên macOS, người dùng gõ một câu tiếng Anh khi mô hình chưa được tải về
- **THEN** hệ thống không kiểm tra câu đó, panel báo cần tải model, còn menu bar và Cài đặt vẫn dùng được

#### Scenario: Thiếu thư mục model trên Windows
- **WHEN** trên Windows, người dùng giải nén app nhưng chưa đặt file model vào thư mục `Models`
- **THEN** panel báo lỗi model và ghi rõ tên file model cần đặt vào thư mục `Models`, còn icon khay và Cài đặt vẫn dùng được
