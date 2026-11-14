# Proposal

## Why

Khi người dùng bôi đen một từ hoặc một đoạn trong ô đang gõ, đó thường là phần họ đang nghi ngờ và muốn kiểm tra. Hiện tại app vẫn kiểm tra cả câu chứa điểm đầu vùng chọn. Muốn kiểm tra đúng phần bôi đen thì phải bấm `⌃⌥G`, và kể cả khi bấm thì đoạn dưới 3 từ cũng không được kiểm tra.

Cụ thể, app đã nhận sự kiện "vùng chọn đổi" từ Accessibility, nhưng chỉ lấy điểm đầu vùng chọn làm vị trí con trỏ, độ dài vùng chọn bị bỏ đi. Thêm vào đó, pipeline có hai chỗ chặn đoạn ngắn:
- Bộ lọc ngôn ngữ bỏ qua đoạn dưới 3 từ.
- Bộ chặn "viết lại câu" coi việc đổi 100% số từ là viết lại. Với đầu vào 1 từ, sửa chính tả `recieve → receive` đã là 100%.

## What Changes

- Khi ô đang focus có vùng chọn không rỗng (sau khi bỏ khoảng trắng), app tự kiểm tra **đúng đoạn bôi đen** thay cho câu chứa con trỏ, kể cả khi chỉ bôi một từ. Không cần bấm phím tắt.
- Bỏ bôi đen (click chỗ khác, hoặc gõ đè lên vùng chọn) thì app quay về kiểm tra câu chứa con trỏ như trước.
- Kéo rộng hoặc thu hẹp vùng chọn thì nội dung kiểm tra cập nhật theo vùng chọn mới, kể cả khi điểm đầu vùng chọn không đổi.
- Vùng chọn dài hơn 1000 ký tự (ví dụ ⌘A cả tài liệu) không được kiểm tra nguyên khối; app dùng câu chứa con trỏ như khi không bôi đen.
- Đoạn bôi đen (tự động, hoặc qua phím tắt `⌃⌥G`) được miễn điều kiện "ít nhất 3 từ". Đoạn dưới 3 từ thì bỏ qua bước nhận diện ngôn ngữ.
- Với đoạn bôi đen dưới 3 từ, bộ chặn "viết lại câu" không áp ngưỡng tổng 80% nhưng vẫn giữ ngưỡng 40% từ bị thay bằng từ khác hẳn.
- Chỉ áp dụng cho macOS. Bản Windows và prompt của model không đổi trong change này.

## Capabilities

### New Capabilities
<!-- Không có. -->

### Modified Capabilities
- `text-capture`: thêm requirement "Ưu tiên đoạn bôi đen trong ô đang focus"; requirement "Tách câu đang chứa con trỏ" chỉ áp dụng khi không có vùng chọn.
- `grammar-correction`: requirement "Chỉ kiểm tra câu tiếng Anh" và "Loại kết quả viết lại câu" có ngoại lệ cho đoạn bôi đen ngắn.

## Impact

- **Code (macOS)**:
  - `GrammarApp/Capture/AXTextCapture.swift`: đọc thêm nội dung vùng chọn (text marker và `AXSelectedText`), so trùng có tính vùng chọn.
  - **Mới** `GrammarKit/Pipeline/CheckTarget.swift`: chọn giữa đoạn bôi đen và câu chứa con trỏ.
  - `GrammarKit/Pipeline/CheckCoordinator.swift`, `LanguageGate.swift`, `GrammarKit/Diff/EditGuard.swift`: thêm nguồn `.selection` và nới điều kiện cho đoạn bôi đen.
  - `GrammarApp/App/AppModel.swift`: nối dây.
- **Không đổi**: prompt và engine, panel, bản Windows (`windows/`).
- **Change đang dở** `add-windows-app`: không bị ảnh hưởng. Bản Windows sẽ làm tương đương ở change sau; cho đến lúc đó, requirement mới chưa đúng trên Windows.
