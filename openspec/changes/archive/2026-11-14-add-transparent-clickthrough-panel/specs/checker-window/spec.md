# Spec Delta

## ADDED Requirements

### Requirement: Click xuyên qua panel
Khi chế độ click xuyên qua đang bật (mặc định), phần nội dung của panel (mọi vùng trừ header) MUST NOT nhận sự kiện chuột. Mọi click, cuộn và kéo trên phần nội dung SHALL được chuyển tới cửa sổ nằm phía sau panel.

#### Scenario: Click vào app phía sau
- **WHEN** chế độ click xuyên qua đang bật, panel nằm đè lên một ô văn bản của TextEdit, và người dùng click vào vùng panel ở đúng vị trí ô đó
- **THEN** con trỏ được đặt vào ô văn bản của TextEdit và panel không phản ứng

#### Scenario: Cuộn trang phía sau
- **WHEN** người dùng cuộn chuột trên vùng panel đang nằm đè lên một trang web
- **THEN** trang web phía sau cuộn theo

### Requirement: Nền trong suốt điều chỉnh được
Nền panel SHALL được vẽ với độ mờ theo cài đặt, từ 0% (trong suốt hoàn toàn) đến 100% (đục), mặc định 75%. Chữ, gạch chân đỏ và phần tô xanh MUST luôn hiển thị đục hoàn toàn, không phụ thuộc độ mờ nền.

#### Scenario: Nền bán trong suốt
- **WHEN** độ mờ nền là 50%
- **THEN** nội dung phía sau panel nhìn thấy được qua nền, còn chữ trong panel vẫn đục và rõ nét

#### Scenario: Nền trong suốt hoàn toàn
- **WHEN** độ mờ nền là 0%
- **THEN** panel không có nền, chỉ còn chữ, gạch chân và phần tô xanh

### Requirement: Header kéo được
Panel SHALL có một header mỏng (khoảng 24 pt) ở cạnh trên, gồm biểu tượng tay nắm và tên "Grammar". Header SHALL luôn nhận chuột, bất kể chế độ click xuyên qua. Kéo header SHALL di chuyển panel, và vị trí mới được lưu như vị trí đã kéo. Nền header MUST có độ mờ tối thiểu 60% để vẫn thấy được khi nền panel trong suốt. Kéo header MUST NOT lấy focus bàn phím của app người dùng đang gõ.

#### Scenario: Kéo panel bằng header
- **WHEN** click xuyên qua đang bật và người dùng nhấn giữ header rồi kéo panel tới giữa màn hình
- **THEN** panel di chuyển theo chuột, vị trí mới được lưu lại, và app đang gõ vẫn giữ focus bàn phím

#### Scenario: Header không cho click xuyên qua
- **WHEN** người dùng click vào header đang nằm đè lên một nút của app phía sau
- **THEN** nút của app phía sau không nhận click

#### Scenario: Phần còn lại vẫn xuyên qua
- **WHEN** click xuyên qua đang bật và người dùng click vào phần nội dung ngay dưới header
- **THEN** click đi xuống cửa sổ phía sau

#### Scenario: Header khi nền trong suốt
- **WHEN** độ mờ nền là 0%
- **THEN** header vẫn hiển thị nền mờ ít nhất 60% và kéo được

### Requirement: Bật/tắt click xuyên qua
Màn hình Cài đặt SHALL có công tắc "Click xuyên qua panel", mặc định bật. Khi tắt, panel SHALL nhận chuột để người dùng kéo panel tới vị trí khác, hiển thị viền để báo panel đang kéo được, và MUST NOT lấy focus bàn phím của app người dùng đang gõ.

#### Scenario: Tắt click xuyên qua để kéo panel
- **WHEN** người dùng tắt "Click xuyên qua panel" rồi kéo panel tới giữa màn hình
- **THEN** panel di chuyển theo chuột, có viền hiển thị, và app đang gõ vẫn giữ focus bàn phím

#### Scenario: Bật lại click xuyên qua
- **WHEN** người dùng bật lại "Click xuyên qua panel"
- **THEN** panel ở nguyên vị trí vừa kéo, viền biến mất, và click trên panel lại đi xuống cửa sổ phía sau

### Requirement: Vị trí panel do người dùng kéo
Vị trí người dùng kéo panel tới SHALL được lưu và dùng thay cho góc đã chọn, kể cả sau khi khởi động lại app. Panel MUST luôn nằm trọn trong vùng hiển thị của màn hình chứa nó. Chọn một góc trong Cài đặt, hoặc bấm "Về góc đã chọn", SHALL bỏ vị trí đã kéo và đặt panel lại theo góc.

#### Scenario: Giữ vị trí sau khi khởi động lại
- **WHEN** người dùng kéo panel tới giữa màn hình rồi thoát và mở lại app
- **THEN** panel hiện ở đúng vị trí đã kéo

#### Scenario: Về góc đã chọn
- **WHEN** panel đang ở vị trí đã kéo và người dùng bấm "Về góc đã chọn" trong Cài đặt
- **THEN** panel trở về góc đang chọn, cách mép 20 pt

#### Scenario: Nội dung dài ra
- **WHEN** panel ở vị trí đã kéo gần mép dưới màn hình và câu kiểm tra dài làm panel cao lên
- **THEN** panel được dời lên để nằm trọn trong vùng hiển thị

### Requirement: Màn hình Cài đặt
Hệ thống SHALL có màn hình Cài đặt, mở từ mục "Cài đặt…" trên menu bar hoặc phím ⌘, khi menu đang mở. Màn hình gồm: độ mờ nền (0–100%), công tắc click xuyên qua, góc màn hình đặt panel (trên phải, trên trái, dưới phải, dưới trái), nút "Về góc đã chọn" khi panel đang ở vị trí đã kéo, và độ rộng panel.

#### Scenario: Mở Cài đặt
- **WHEN** người dùng chọn "Cài đặt…" trên menu bar
- **THEN** cửa sổ Cài đặt hiện lên phía trước

#### Scenario: Thay đổi áp dụng ngay
- **WHEN** người dùng kéo thanh trượt độ mờ nền, hoặc đổi góc hay độ rộng
- **THEN** panel cập nhật ngay, không cần bấm lưu hay khởi động lại

### Requirement: Lưu cài đặt panel
Các giá trị độ mờ nền, góc, độ rộng, trạng thái click xuyên qua và vị trí đã kéo SHALL được lưu trên máy và áp dụng lại khi app khởi động. Giá trị không hợp lệ hoặc chưa có SHALL được thay bằng mặc định: độ mờ 75%, góc trên phải, độ rộng 460 pt, click xuyên qua bật, không có vị trí đã kéo.

#### Scenario: Khởi động lại app
- **WHEN** người dùng đặt độ mờ nền 30%, góc dưới trái, rồi thoát và mở lại app
- **THEN** panel hiện ở góc dưới trái với nền mờ 30%

### Requirement: Vị trí panel theo góc màn hình
Khi không có vị trí đã kéo, panel SHALL được đặt ở góc màn hình đã chọn, trong vùng hiển thị của màn hình chính (không đè menu bar và Dock), cách mép 20 pt. Chiều cao panel SHALL tự co theo nội dung.

#### Scenario: Góc dưới phải
- **WHEN** góc đã chọn là dưới phải
- **THEN** cạnh phải và cạnh dưới của panel cách mép vùng hiển thị 20 pt

## MODIFIED Requirements

### Requirement: Không ghi vào app khác
Hệ thống MUST NOT tự thay đổi nội dung trong app mà người dùng đang gõ. Người dùng SHALL copy được câu đã sửa qua mục "Copy câu đã sửa" trên menu bar hoặc phím tắt toàn cục `⌃⌥C`.

#### Scenario: Copy câu sửa
- **WHEN** panel đang hiển thị câu đã sửa "He has two cats." và người dùng bấm `⌃⌥C`
- **THEN** "He has two cats." được copy vào clipboard, còn app nguồn không bị thay đổi

#### Scenario: Copy khi không có câu sửa
- **WHEN** trạng thái không phải "có lỗi" (ví dụ không có lỗi ngữ pháp, hoặc đang kiểm tra) và người dùng bấm `⌃⌥C`
- **THEN** clipboard không bị thay đổi

### Requirement: Điều khiển qua menu bar
Hệ thống SHALL có biểu tượng trên menu bar với các lựa chọn: Hiện/Ẩn panel, Tạm dừng/Tiếp tục theo dõi, Copy câu đã sửa, Cài đặt…, và Thoát. Mục "Copy câu đã sửa" SHALL bị vô hiệu khi không có câu sửa. App SHALL không hiển thị icon trên Dock.

#### Scenario: Tạm dừng
- **WHEN** người dùng chọn "Tạm dừng" trên menu bar
- **THEN** hệ thống ngừng đọc ô nhập liệu và ngừng kiểm tra cho đến khi chọn "Tiếp tục"

#### Scenario: Ẩn panel
- **WHEN** người dùng chọn "Ẩn panel"
- **THEN** panel biến mất, còn icon menu bar vẫn còn

#### Scenario: Copy từ menu bar
- **WHEN** panel đang hiển thị câu đã sửa và người dùng chọn "Copy câu đã sửa"
- **THEN** câu đã sửa được copy vào clipboard
