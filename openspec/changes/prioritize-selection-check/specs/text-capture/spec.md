# Spec Delta

## ADDED Requirements

### Requirement: Ưu tiên đoạn bôi đen trong ô đang focus
Trên macOS, khi ô nhập liệu đang focus có vùng chọn không rỗng (sau khi bỏ khoảng trắng hai đầu) và dài tối đa 1000 ký tự (UTF-16), hệ thống SHALL tự lấy đúng đoạn bôi đen để kiểm tra thay cho câu chứa con trỏ, mà không cần phím tắt. Nội dung kiểm tra SHALL cập nhật khi vùng chọn đổi. Khi vùng chọn rỗng hoặc dài hơn giới hạn, hệ thống SHALL lấy câu chứa con trỏ.

#### Scenario: Bôi đen một từ
- **WHEN** ô chứa "I will recieve it tomorrow." và người dùng bôi đen "recieve"
- **THEN** đoạn được lấy để kiểm tra là "recieve", không phải cả câu

#### Scenario: Bôi đen nhiều câu
- **WHEN** ô chứa "I like tea. He have two cats. We is fine." và người dùng bôi đen từ "He" tới hết "fine."
- **THEN** đoạn được lấy để kiểm tra là "He have two cats. We is fine."

#### Scenario: Bỏ bôi đen
- **WHEN** người dùng đang bôi đen "recieve" rồi click vào một chỗ khác trong câu "I will recieve it tomorrow."
- **THEN** đoạn được lấy để kiểm tra quay về câu chứa con trỏ "I will recieve it tomorrow."

#### Scenario: Kéo rộng vùng chọn
- **WHEN** người dùng bôi đen "He" rồi kéo rộng vùng chọn sang phải thành "He have two cats", điểm đầu vùng chọn không đổi
- **THEN** đoạn được lấy để kiểm tra được cập nhật thành "He have two cats"

#### Scenario: Vùng chọn chỉ có khoảng trắng
- **WHEN** người dùng bôi đen một vùng chỉ gồm dấu cách hoặc xuống dòng
- **THEN** hệ thống coi như không có vùng chọn và lấy câu chứa con trỏ

#### Scenario: Vùng chọn quá dài
- **WHEN** người dùng bấm ⌘A trong một tài liệu dài hơn 1000 ký tự
- **THEN** hệ thống không kiểm tra cả tài liệu mà lấy câu chứa con trỏ

#### Scenario: Bôi đen trong trình soạn thảo web
- **WHEN** người dùng bôi đen "envidences" trong một trang Confluence trên Chrome
- **THEN** đoạn được lấy để kiểm tra là "envidences"

#### Scenario: Ô mật khẩu có vùng chọn
- **WHEN** người dùng bôi đen nội dung trong một ô mật khẩu
- **THEN** hệ thống không đọc gì và panel không hiển thị gì từ ô đó

#### Scenario: Đang tạm dừng
- **WHEN** app đang tạm dừng theo dõi và người dùng bôi đen một từ
- **THEN** hệ thống không kiểm tra đoạn đó

## MODIFIED Requirements

### Requirement: Tách câu đang chứa con trỏ
Khi ô nhập liệu không có vùng chọn được ưu tiên (xem "Ưu tiên đoạn bôi đen trong ô đang focus"), hệ thống SHALL chỉ lấy câu đang chứa con trỏ trong ô nhập liệu để kiểm tra. Nếu không xác định được vị trí con trỏ, hệ thống SHALL lấy câu cuối cùng trong ô. Với trình soạn thảo có nhiều đoạn văn và định dạng (code inline, mention, ảnh nhúng), câu được lấy MUST nằm trong đúng đoạn văn đang chứa con trỏ.

#### Scenario: Ô có nhiều câu
- **WHEN** ô chứa "I like tea. He have two cats. We are fine." và con trỏ nằm trong câu thứ hai
- **THEN** câu được lấy ra là "He have two cats."

#### Scenario: Không có thông tin con trỏ
- **WHEN** app nguồn không cung cấp vị trí con trỏ
- **THEN** hệ thống lấy câu cuối cùng trong ô

#### Scenario: Trình soạn thảo web có định dạng
- **WHEN** trong một trang Confluence trên Chrome, phía trên có đoạn "Upgrade React Native from 0.83.1 to 0.87.1 across both mobile apps - apps/superapp-mobile … along with the matching react / react-dom (19.2.3) and native-module bumps." chứa code inline, và người dùng đang gõ "I don't want to mention" ở đoạn mới bên dưới với con trỏ ở cuối dòng
- **THEN** câu được lấy ra là "I don't want to mention", không phải đoạn phía trên

#### Scenario: Con trỏ ở giữa trang
- **WHEN** trong cùng trang đó, người dùng đặt con trỏ vào giữa đoạn "Upgrade React Native…"
- **THEN** câu được lấy ra là câu chứa con trỏ trong đoạn "Upgrade React Native…"
