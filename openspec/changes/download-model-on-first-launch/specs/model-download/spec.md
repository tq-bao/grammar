# Spec Delta

## Purpose

Đưa model ngôn ngữ về máy ở lần mở app đầu tiên trên macOS, thay vì đóng gói model kèm file cài. Nhờ vậy file cài nhỏ, còn người dùng vẫn biết mình sắp tải gì và tự quyết định có tải hay không.

## ADDED Requirements

### Requirement: Hỏi trước khi tải model
Trên macOS, khi app khởi động mà không tìm thấy model, hệ thống SHALL hiện hộp thoại cho biết model chỉ tải một lần và được lưu trên máy, và cho người dùng chọn "Tải ngay" hoặc "Để sau". Hệ thống MUST NOT bắt đầu tải khi người dùng chưa đồng ý. Hộp thoại, panel và menu bar MUST NOT hiển thị dung lượng của model.

#### Scenario: Lần mở đầu tiên
- **WHEN** người dùng mở app lần đầu và trên máy chưa có model
- **THEN** hộp thoại hỏi tải model hiện lên phía trước, không nêu dung lượng model, và chưa có dữ liệu nào được tải

#### Scenario: Chọn Để sau
- **WHEN** người dùng chọn "Để sau" trong hộp thoại
- **THEN** app không tải gì, panel báo cần tải model, và menu bar có mục "Tải model…"

#### Scenario: Đã có model
- **WHEN** người dùng mở app và model đã có trên máy
- **THEN** không có hộp thoại nào hiện lên, và app nạp model như bình thường

### Requirement: Tải model từ menu bar
Khi chưa có model, menu bar SHALL có mục "Tải model…" để bắt đầu tải. Trong lúc tải, menu bar SHALL hiển thị tiến độ theo phần trăm và có mục "Huỷ tải". Khi model đã sẵn sàng, các mục này MUST NOT hiển thị.

#### Scenario: Tải từ menu bar
- **WHEN** người dùng đã chọn "Để sau", sau đó chọn "Tải model…" trên menu bar
- **THEN** việc tải bắt đầu, và panel cùng menu bar hiển thị tiến độ

#### Scenario: Huỷ tải
- **WHEN** đang tải và người dùng chọn "Huỷ tải"
- **THEN** việc tải dừng lại, phần đã tải được giữ lại để tải tiếp, và menu bar lại có mục để tải model

#### Scenario: Model đã sẵn sàng
- **WHEN** model đã được tải xong và nạp thành công
- **THEN** menu bar không còn mục tải model hay huỷ tải

### Requirement: Nơi lưu model
Model đã tải SHALL được lưu trong thư mục dữ liệu của người dùng (`~/Library/Application Support/Grammar/Models/`), không nằm trong app. Cài lại hoặc cập nhật app MUST NOT làm mất model đã tải, và MUST NOT bắt người dùng tải lại.

#### Scenario: Cập nhật app
- **WHEN** người dùng đã tải model, sau đó cài đè một bản app mới hơn rồi mở app
- **THEN** app dùng ngay model đã tải, không hỏi tải lại

### Requirement: Tải tiếp sau khi bị ngắt
Khi việc tải bị ngắt (mất mạng, người dùng huỷ, hoặc app bị thoát), hệ thống SHALL giữ phần đã tải. Lần tải sau SHALL tiếp tục từ phần đó thay vì tải lại từ đầu.

#### Scenario: Mất mạng giữa chừng
- **WHEN** đã tải được 2 GB thì mất mạng, sau đó người dùng thoát app, mở lại và đồng ý tải
- **THEN** việc tải tiếp tục từ khoảng 2 GB, và hộp thoại cho biết phần trăm đã tải ở lần trước, không nêu dung lượng

### Requirement: Kiểm tra dung lượng trống
Trước khi tải, hệ thống SHALL kiểm tra ổ đĩa có đủ chỗ cho phần còn lại của model, cộng thêm một khoảng dự phòng. Nếu không đủ, hệ thống MUST NOT bắt đầu tải, và SHALL báo lỗi ghi rõ dung lượng cần có.

#### Scenario: Ổ đĩa gần đầy
- **WHEN** ổ đĩa chỉ còn 2 GB trống và người dùng chọn tải model
- **THEN** việc tải không bắt đầu, và panel báo không đủ dung lượng, kèm số GB cần giải phóng

### Requirement: Kiểm tra toàn vẹn model
Sau khi tải xong, hệ thống SHALL kiểm tra file là model GGUF và có checksum SHA256 khớp với giá trị đã ghim trong app. File không đạt MUST NOT được nạp, MUST bị xoá, và hệ thống SHALL báo lỗi kèm cách thử lại.

#### Scenario: File tải về bị hỏng
- **WHEN** file tải về có checksum không khớp
- **THEN** file bị xoá, app không nạp file đó, panel báo lỗi model, và menu bar có mục để tải lại

#### Scenario: File hợp lệ
- **WHEN** file tải về đúng định dạng GGUF và đúng checksum
- **THEN** app nạp model, và người dùng kiểm tra được câu ngay mà không cần khởi động lại

### Requirement: Lỗi khi tải
Khi việc tải thất bại (không có mạng, lỗi máy chủ, hết dung lượng), hệ thống SHALL báo lỗi rõ ràng trên panel và cho thử lại từ menu bar. App MUST tiếp tục chạy, không crash.

#### Scenario: Không có mạng khi bắt đầu tải
- **WHEN** máy không có mạng và người dùng chọn tải model
- **THEN** panel báo không tải được model kèm lý do, menu bar có mục thử lại, và app vẫn chạy

### Requirement: Không gửi nội dung người dùng khi tải
Việc tải model SHALL chỉ gửi yêu cầu tải đúng file model đã định sẵn. Hệ thống MUST NOT gửi nội dung người dùng gõ, câu đã sửa hay thông tin về app đang dùng.

#### Scenario: Đang gõ trong lúc tải
- **WHEN** model đang được tải và người dùng gõ "She go to school." trong Slack
- **THEN** câu đó không có trong bất kỳ yêu cầu mạng nào của app

### Requirement: Chỉ có trên macOS
Việc tải model ở lần mở đầu tiên SHALL chỉ áp dụng cho bản macOS. Bản Windows MUST giữ cách đặt file model vào thư mục `Models` cạnh file chạy của app.

#### Scenario: Bản Windows
- **WHEN** người dùng mở bản Windows mà chưa có model trong thư mục `Models`
- **THEN** app không hỏi tải model, mà báo lỗi model như hiện nay
