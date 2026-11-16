## MODIFIED Requirements

### Requirement: Trạng thái kiểm tra
Panel SHALL hiển thị trạng thái hiện tại: đang chờ, đang kiểm tra, không có lỗi, có lỗi, không phải tiếng Anh, không chắc chắn, lỗi model, cần tải model, hoặc đang tải model. Khi đang tải model, panel SHALL hiển thị thanh tiến độ kèm phần trăm đã tải, và MUST NOT hiển thị dung lượng model.

#### Scenario: Câu đúng
- **WHEN** câu gốc không có lỗi
- **THEN** phần trên không có gạch chân và panel báo "Không có lỗi ngữ pháp"

#### Scenario: Đang kiểm tra
- **WHEN** mô hình đang xử lý câu
- **THEN** panel hiển thị trạng thái đang kiểm tra

#### Scenario: Cần tải model
- **WHEN** trên macOS chưa có model và người dùng chưa bắt đầu tải
- **THEN** panel báo "Cần tải model" và hướng dẫn mở menu bar, chọn "Tải model…"

#### Scenario: Đang tải model
- **WHEN** model đang được tải và đã tải được 1.2 GB trên 4.7 GB
- **THEN** panel báo "Đang tải model", có thanh tiến độ đầy khoảng một phần tư và chữ "25%" cạnh thanh, không có số GB
