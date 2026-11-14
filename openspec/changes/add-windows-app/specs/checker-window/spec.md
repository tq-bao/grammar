# Spec Delta

## MODIFIED Requirements

### Requirement: Không ghi vào app khác
Hệ thống MUST NOT tự thay đổi nội dung trong app mà người dùng đang gõ. Người dùng SHALL copy được câu đã sửa qua mục "Copy câu đã sửa" trên menu bar (macOS) hoặc trên menu của icon khay hệ thống (Windows). Trên macOS còn có thêm phím tắt toàn cục `⌃⌥C`. Trên Windows không có phím tắt.

#### Scenario: Copy câu sửa
- **WHEN** trên macOS, panel đang hiển thị câu đã sửa "He has two cats." và người dùng bấm `⌃⌥C`
- **THEN** "He has two cats." được copy vào clipboard, còn app nguồn không bị thay đổi

#### Scenario: Copy khi không có câu sửa
- **WHEN** trạng thái không phải "có lỗi" (ví dụ không có lỗi ngữ pháp, hoặc đang kiểm tra) và người dùng bấm `⌃⌥C` (macOS) hoặc mở menu khay (Windows)
- **THEN** clipboard không bị thay đổi, và mục "Copy câu đã sửa" bị vô hiệu

#### Scenario: Copy câu sửa trên Windows
- **WHEN** trên Windows, panel đang hiển thị câu đã sửa "He has two cats." và người dùng chọn "Copy câu đã sửa" trên menu khay
- **THEN** "He has two cats." được copy vào clipboard, còn app nguồn không bị thay đổi

### Requirement: Điều khiển qua menu bar
Hệ thống SHALL có biểu tượng trên menu bar (macOS) hoặc khay hệ thống (Windows) với các lựa chọn: Hiện/Ẩn panel, Tạm dừng/Tiếp tục theo dõi, Copy câu đã sửa, Cài đặt…, và Thoát. Mục "Copy câu đã sửa" SHALL bị vô hiệu khi không có câu sửa. App SHALL không hiển thị icon trên Dock (macOS) và không có nút trên taskbar (Windows).

#### Scenario: Tạm dừng
- **WHEN** người dùng chọn "Tạm dừng" trên menu bar
- **THEN** hệ thống ngừng đọc ô nhập liệu và ngừng kiểm tra cho đến khi chọn "Tiếp tục"

#### Scenario: Ẩn panel
- **WHEN** người dùng chọn "Ẩn panel"
- **THEN** panel biến mất, còn icon menu bar vẫn còn

#### Scenario: Copy từ menu bar
- **WHEN** panel đang hiển thị câu đã sửa và người dùng chọn "Copy câu đã sửa"
- **THEN** câu đã sửa được copy vào clipboard

#### Scenario: Menu khay trên Windows
- **WHEN** trên Windows, app đang chạy và người dùng click chuột phải vào icon Grammar ở khay hệ thống
- **THEN** menu hiện đủ các mục Hiện/Ẩn panel, Tạm dừng/Tiếp tục, Copy câu đã sửa, Cài đặt…, Thoát, và taskbar không có nút nào của Grammar

### Requirement: Màn hình Cài đặt
Hệ thống SHALL có màn hình Cài đặt, mở từ mục "Cài đặt…" trên menu bar (macOS) hoặc menu khay (Windows). Trên macOS còn mở được bằng phím ⌘, khi menu đang mở. Màn hình gồm: độ mờ nền (0–100%), công tắc click xuyên qua, góc màn hình đặt panel (trên phải, trên trái, dưới phải, dưới trái), nút "Về góc đã chọn" khi panel đang ở vị trí đã kéo, và độ rộng panel. Trên Windows còn có mục chọn model và dòng cho biết model đang chạy trên GPU hay CPU.

#### Scenario: Mở Cài đặt
- **WHEN** người dùng chọn "Cài đặt…" trên menu bar
- **THEN** cửa sổ Cài đặt hiện lên phía trước

#### Scenario: Thay đổi áp dụng ngay
- **WHEN** người dùng kéo thanh trượt độ mờ nền, hoặc đổi góc hay độ rộng
- **THEN** panel cập nhật ngay, không cần bấm lưu hay khởi động lại

#### Scenario: Cài đặt trên Windows
- **WHEN** trên Windows, người dùng chọn "Cài đặt…" trên menu khay
- **THEN** cửa sổ Cài đặt hiện lên phía trước, có đủ các mục như macOS, cùng mục chọn model và dòng "Đang chạy trên: GPU" hoặc "Đang chạy trên: CPU"

### Requirement: Vị trí panel theo góc màn hình
Khi không có vị trí đã kéo, panel SHALL được đặt ở góc màn hình đã chọn, trong vùng hiển thị của màn hình chính, cách mép 20 pt. Trên macOS, vùng hiển thị không đè menu bar và Dock. Trên Windows, vùng hiển thị không đè taskbar, ở bất kỳ cạnh nào taskbar đang nằm. Chiều cao panel SHALL tự co theo nội dung.

#### Scenario: Góc dưới phải
- **WHEN** góc đã chọn là dưới phải
- **THEN** cạnh phải và cạnh dưới của panel cách mép vùng hiển thị 20 pt

#### Scenario: Taskbar ở cạnh dưới trên Windows
- **WHEN** trên Windows, taskbar nằm ở cạnh dưới màn hình và góc đã chọn là dưới phải
- **THEN** cạnh dưới của panel cách mép trên của taskbar 20 pt, và panel không bị taskbar che

## ADDED Requirements

### Requirement: Kích thước theo DPI trên Windows
Trên Windows, mọi kích thước tính bằng pt trong spec này (độ rộng panel, chiều cao header, khoảng cách tới mép) SHALL được hiểu là đơn vị độc lập thiết bị (1/96 inch). Panel SHALL hiển thị đúng kích thước và chữ rõ nét ở mọi mức scale màn hình, kể cả khi bị kéo sang màn hình có scale khác.

#### Scenario: Màn hình scale 150%
- **WHEN** trên Windows, màn hình đặt scale 150% và độ rộng panel là 460
- **THEN** panel rộng 690 pixel vật lý và chữ không bị mờ

#### Scenario: Kéo sang màn hình khác scale
- **WHEN** người dùng kéo panel từ màn hình scale 100% sang màn hình scale 150%
- **THEN** panel giữ cùng kích thước nhìn thấy, chữ vẫn rõ nét, và panel nằm trọn trong vùng hiển thị của màn hình mới

### Requirement: Chỉ một bản app chạy trên Windows
Trên Windows, khi app đang chạy mà người dùng mở app thêm lần nữa, hệ thống MUST NOT tạo thêm panel hay icon khay thứ hai. Bản đang chạy SHALL hiện panel nếu panel đang ẩn.

#### Scenario: Mở app lần hai
- **WHEN** trên Windows, Grammar đang chạy với panel đang ẩn và người dùng chạy lại `Grammar.exe`
- **THEN** khay hệ thống chỉ có một icon Grammar, chỉ có một panel, và panel hiện lên
