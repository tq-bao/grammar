# Proposal

## Why

Panel kiểm tra ngữ pháp luôn nổi trên cùng, có nền đục và nhận chuột. Vì vậy nó che nội dung và cản thao tác ở app người dùng đang làm việc. Người dùng muốn panel trở thành một lớp hiển thị thuần: nhìn xuyên được, click xuyên được, và tự chỉnh được độ trong suốt.

## What Changes

- Nền panel bán trong suốt. Độ mờ nền chỉnh được từ 0% đến 100%. Chữ, gạch chân đỏ và phần tô xanh vẫn rõ nét.
- Panel **cho click xuyên qua** (mặc định bật): mọi click và cuộn chuột trên vùng panel đều đi tới cửa sổ phía sau. Panel chỉ để xem, không có titlebar.
- Có công tắc bật/tắt click xuyên qua trong Cài đặt. Khi tắt, người dùng kéo được panel tới vị trí bất kỳ. Vị trí đã kéo được lưu lại và dùng thay cho góc.
- Thêm màn hình **Cài đặt**, mở từ menu bar bằng "Cài đặt…" hoặc ⌘,. Gồm độ mờ nền, công tắc click xuyên qua, góc màn hình đặt panel (4 góc), nút "Về góc đã chọn" và độ rộng panel. Thay đổi áp dụng ngay và được lưu lại sau khi khởi động lại app.
- Copy câu đã sửa qua mục menu bar "Copy câu đã sửa" và phím tắt toàn cục `⌃⌥C`, thay cho việc bôi đen hoặc bấm nút trong panel.
- Hướng dẫn cấp quyền Accessibility có thêm mục mở System Settings trên menu bar, vì nút trong panel không còn bấm được.
- **BREAKING**: bỏ tính năng gõ hoặc dán câu trực tiếp vào panel. Dùng phím tắt `⌃⌥G` cho đoạn bôi đen thay thế.

## Capabilities

### New Capabilities
<!-- Không có. -->

### Modified Capabilities
- `checker-window`: thêm click xuyên qua (bật/tắt được), kéo panel khi tắt click xuyên qua và lưu vị trí đã kéo, nền trong suốt điều chỉnh được, màn hình Cài đặt (độ mờ, góc, độ rộng). Copy câu sửa chuyển sang menu bar và phím tắt. Menu bar có thêm "Cài đặt…" và "Copy câu đã sửa".
- `text-capture`: bỏ requirement nhập tay vào panel. Bỏ scenario gõ trong panel ở phần loại trừ nội dung nhạy cảm. Hướng dẫn cấp quyền mở System Settings từ menu bar.

## Impact

- **Code**:
  - `GrammarApp/UI/CheckerPanel.swift`: borderless, trong suốt, bỏ qua chuột, đặt theo góc.
  - `GrammarApp/UI/TwoPaneView.swift`: phần trên chỉ đọc, nền chung trong suốt, bỏ nút Copy.
  - `GrammarApp/App/AppModel.swift`, `GrammarApp/App/GrammarApp.swift`: scene Settings, mục menu mới.
  - `GrammarApp/Capture/SelectionHotkey.swift`: thêm phím tắt `⌃⌥C`.
  - File mới cho cài đặt và màn hình Cài đặt.
- **Dữ liệu**: lưu 5 giá trị cài đặt trong `UserDefaults`. Không lưu nội dung người dùng gõ.
- **Không đổi**: logic kiểm tra ngữ pháp, engine, model và pipeline trong `GrammarKit`.
- **Rủi ro**: khi đã bỏ nhập tay, nếu quyền Accessibility bị chặn thì app không còn cách nào nhận câu.
