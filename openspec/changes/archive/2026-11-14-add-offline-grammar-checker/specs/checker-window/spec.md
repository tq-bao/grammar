# Spec Delta

## Purpose

Hiển thị kết quả kiểm tra ngữ pháp trong cửa sổ riêng của app. Người dùng thấy ngay cụm từ sai trong câu mình gõ và câu đã sửa, mà không bị gián đoạn khi đang gõ ở app khác.

## ADDED Requirements

### Requirement: Panel hai phần
Hệ thống SHALL hiển thị một panel gồm hai phần. Phần trên hiển thị câu gốc đang được kiểm tra. Phần dưới hiển thị câu đã sửa.

#### Scenario: Có lỗi ngữ pháp
- **WHEN** câu gốc là "She go to school yesterday." và câu sửa là "She went to school yesterday."
- **THEN** phần trên hiển thị "She go to school yesterday." và phần dưới hiển thị "She went to school yesterday."

### Requirement: Gạch chân đỏ cụm sai
Ở phần trên, hệ thống SHALL gạch chân màu đỏ đúng những từ trong câu gốc bị thay đổi hoặc bị xoá trong câu sửa. Vị trí gạch chân SHALL được xác định bằng cách so sánh câu gốc với câu sửa theo từng từ.

#### Scenario: Thay một từ
- **WHEN** câu gốc là "He have two cats." và câu sửa là "He has two cats."
- **THEN** chỉ từ "have" ở phần trên bị gạch chân đỏ

#### Scenario: Thiếu từ
- **WHEN** câu gốc là "I going home." và câu sửa là "I am going home."
- **THEN** phần trên có dấu đỏ ở chỗ thiếu từ, giữa "I" và "going"

### Requirement: Làm nổi bật phần đã sửa
Ở phần dưới, hệ thống SHALL làm nổi bật (khác màu với phần còn lại) những từ được thêm vào hoặc thay đổi so với câu gốc.

#### Scenario: Từ được thay
- **WHEN** câu sửa là "He has two cats." từ câu gốc "He have two cats."
- **THEN** từ "has" ở phần dưới được làm nổi bật

### Requirement: Trạng thái kiểm tra
Panel SHALL hiển thị trạng thái hiện tại: đang chờ, đang kiểm tra, không có lỗi, có lỗi, không phải tiếng Anh, không chắc chắn, hoặc lỗi model.

#### Scenario: Câu đúng
- **WHEN** câu gốc không có lỗi
- **THEN** phần trên không có gạch chân và panel báo "Không có lỗi ngữ pháp"

#### Scenario: Đang kiểm tra
- **WHEN** mô hình đang xử lý câu
- **THEN** panel hiển thị trạng thái đang kiểm tra

### Requirement: Panel không lấy focus
Panel SHALL luôn nằm trên các cửa sổ khác và MUST NOT lấy focus khỏi app người dùng đang gõ khi nội dung của panel được cập nhật.

#### Scenario: Cập nhật khi đang gõ
- **WHEN** panel cập nhật kết quả trong lúc người dùng đang gõ trong Slack
- **THEN** con trỏ vẫn ở trong Slack và người dùng gõ tiếp bình thường

### Requirement: Không ghi vào app khác
Hệ thống MUST NOT tự thay đổi nội dung trong app mà người dùng đang gõ. Người dùng SHALL có thể chọn và copy câu đã sửa từ phần dưới của panel.

#### Scenario: Copy câu sửa
- **WHEN** người dùng chọn câu ở phần dưới và bấm ⌘C
- **THEN** câu đã sửa được copy vào clipboard, còn app nguồn không bị thay đổi

### Requirement: Điều khiển qua menu bar
Hệ thống SHALL có biểu tượng trên menu bar với các lựa chọn Hiện/Ẩn panel, Tạm dừng/Tiếp tục theo dõi, và Thoát. App SHALL không hiển thị icon trên Dock.

#### Scenario: Tạm dừng
- **WHEN** người dùng chọn "Tạm dừng" trên menu bar
- **THEN** hệ thống ngừng đọc ô nhập liệu và ngừng kiểm tra cho đến khi chọn "Tiếp tục"

#### Scenario: Ẩn panel
- **WHEN** người dùng chọn "Ẩn panel"
- **THEN** panel biến mất, còn icon menu bar vẫn còn
