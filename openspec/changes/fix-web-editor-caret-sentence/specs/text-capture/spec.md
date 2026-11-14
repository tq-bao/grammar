# Spec Delta

## MODIFIED Requirements

### Requirement: Tách câu đang chứa con trỏ
Hệ thống SHALL chỉ lấy câu đang chứa con trỏ trong ô nhập liệu để kiểm tra. Nếu không xác định được vị trí con trỏ, hệ thống SHALL lấy câu cuối cùng trong ô. Với trình soạn thảo có nhiều đoạn văn và định dạng (code inline, mention, ảnh nhúng), câu được lấy MUST nằm trong đúng đoạn văn đang chứa con trỏ.

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
