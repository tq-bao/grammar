# Tasks

## 1. Logic thuần trong GrammarKit

- [x] 1.1 Thêm `PanelCorner` và `PanelLayout.frame(corner:size:visibleFrame:margin:)` vào GrammarKit. Kiểm tra: unit test cho cả 4 góc với một `visibleFrame` có gốc khác (0,0) (mô phỏng Dock và menu bar), cạnh panel cách mép đúng 20 pt, và panel rộng hơn màn hình thì bị kẹp vào trong.
- [x] 1.2 Đổi `DiffHighlighter` sang trả về `AttributedString` với attribute của SwiftUI (`originalText`: gạch chân đỏ và nền đỏ nhạt ở chỗ thiếu từ; `correctedText`: xanh, đậm), bỏ hai API dùng `NSAttributedString`. Kiểm tra: cập nhật `DiffHighlighterTests` để kiểm tra attribute trên `AttributedString` ("He have" → "have" gạch chân đỏ, "has" màu xanh), và toàn bộ test cũ vẫn pass.

## 2. Cài đặt panel

- [x] 2.1 Viết `PanelSettings` (`@Observable`): `backgroundOpacity` (0…1, mặc định 0.75), `corner` (mặc định `topRight`), `width` (320…700, mặc định 460), lưu và đọc `UserDefaults`, kẹp giá trị khi nạp, có hàm `resetToDefaults()`. Kiểm tra: unit test với `UserDefaults(suiteName:)` riêng: giá trị được lưu và đọc lại đúng, giá trị ngoài khoảng bị kẹp, key thiếu thì dùng mặc định. Nếu cần, chuyển phần thuần sang GrammarKit để test được.
- [x] 2.2 Viết `SettingsView` và thêm scene `Settings` vào `GrammarApp` (thanh trượt độ mờ có hiện %, chọn góc, thanh trượt độ rộng, nút "Khôi phục mặc định"). Kiểm tra bằng tay: mở từ menu bar "Cài đặt…" thì cửa sổ hiện lên trước; kéo thanh trượt thì panel đổi ngay.

## 3. Panel trong suốt và click xuyên qua

- [x] 3.1 Sửa `CheckerPanel`: style borderless + nonactivating, `ignoresMouseEvents = true`, `isOpaque = false`, nền `.clear`, `canBecomeKey = false`, bỏ autosave frame (và xoá key autosave cũ), đặt khung bằng `PanelLayout` theo `NSScreen.screens.first?.visibleFrame`, chiều cao lấy từ `fittingSize` của hosting view, đặt lại khung khi nội dung, cài đặt hoặc màn hình đổi. Kiểm tra bằng tay: click vào vùng panel đè lên TextEdit thì con trỏ vào TextEdit; cuộn trên panel thì trang phía sau cuộn; đổi góc và độ rộng thì panel di chuyển ngay; câu dài thì panel cao lên.
- [x] 3.2 Sửa `TwoPaneView`: một nền `RoundedRectangle` chung với độ mờ theo cài đặt, phần trên và phần dưới dùng `Text` với `DiffHighlighter.originalText` và `correctedText`, chữ có shadow nhẹ, bỏ `OriginalTextEditor`, `CorrectedTextView` và nút Copy, bỏ nút trong `PermissionView` (chữ hướng dẫn trỏ tới menu bar). Kiểm tra bằng tay: độ mờ 50% thì thấy nội dung phía sau mà chữ vẫn rõ; độ mờ 0% thì chỉ còn chữ và gạch chân, vẫn đọc được trên nền trắng và nền tối.

## 4. Copy câu sửa và menu bar

- [x] 4.1 Tách `GlobalHotkeys` (một event handler Carbon, nhiều phím theo `EventHotKeyID.id`), chuyển `⌃⌥G` sang dùng nó và thêm `⌃⌥C`. `SelectionHotkey` chỉ còn phần giả lập ⌘C và lưu, khôi phục clipboard. Kiểm tra bằng tay: `⌃⌥G` vẫn hoạt động như trước.
- [x] 4.2 Thêm `AppModel.copyCorrection()` và `canCopyCorrection` (chỉ khi state là `.corrected`), gắn vào `⌃⌥C` và mục menu "Copy câu đã sửa". Kiểm tra bằng tay: đang có câu sửa thì bấm `⌃⌥C` hoặc chọn menu, sau đó dán vào TextEdit ra đúng câu sửa; khi "Không có lỗi" thì menu bị vô hiệu và `⌃⌥C` không đổi clipboard.
- [x] 4.3 Cập nhật `MenuBarContent`: thứ tự Hiện/Ẩn panel, Tạm dừng/Tiếp tục, Copy câu đã sửa, "Cấp quyền Accessibility…" (chỉ khi chưa có quyền), "Cài đặt…" (⌘,), Thoát. Kiểm tra bằng tay: các mục hiện đúng điều kiện; gỡ quyền Accessibility rồi chạy app thì thấy mục cấp quyền, cấp quyền xong thì mục này biến mất.

## 6. Bật/tắt click xuyên qua và kéo panel

- [x] 6.1 Thêm vào `PanelSettings` thuộc tính `clickThrough` (mặc định `true`), `customTopLeft` (lưu `[x, y]`) và hàm `resetPosition()`. Đổi `corner` hoặc gọi `resetToDefaults()` thì xoá `customTopLeft`. Thêm `PanelLayout.frame(topLeft:size:visibleFrame:)` (kẹp vào vùng hiển thị). Kiểm tra: unit test lưu và đọc lại 2 thuộc tính mới, việc đổi góc xoá vị trí đã kéo, và việc kẹp panel khi vị trí đã kéo nằm sát mép hoặc nằm ngoài màn hình.
- [x] 6.2 `CheckerPanel`: `ignoresMouseEvents` theo `clickThrough`; khi tắt click xuyên qua thì `hitTest` trả về hosting view và `mouseDown` gọi `performDrag`; nghe `didMoveNotification` để lưu `customTopLeft` (bỏ qua lúc `relayout()` gọi `setFrame`); đặt khung theo `customTopLeft` nếu có, không thì theo góc. `TwoPaneView` vẽ viền khi đang tắt click xuyên qua. Kiểm tra bằng tay: tắt rồi kéo panel tới giữa màn hình, app đang gõ vẫn giữ focus; bật lại thì panel ở nguyên chỗ và click lại đi xuyên qua; thoát rồi mở lại app thì panel vẫn ở chỗ đã kéo.
- [x] 6.3 `SettingsView`: thêm công tắc "Click xuyên qua panel" (kèm dòng giải thích), và nút "Về góc đã chọn" khi đang có vị trí đã kéo. Cập nhật README. Kiểm tra bằng tay: bật/tắt công tắc thì panel đổi chế độ ngay; bấm "Về góc đã chọn" thì panel về góc.

## 7. Header kéo được

- [x] 7.1 Thêm `PanelLayout.headerHeight` (24) và `PanelLayout.headerRect(in:)` vào GrammarKit. Kiểm tra: unit test cho dải header của một khung panel, với điểm nằm trong, ngay dưới, và ở mép trên.
- [x] 7.2 `CheckerPanel`: global mouse monitor + tracking area để bật/tắt `ignoresMouseEvents` khi chuột ở trên header; `hitTest` và `mouseDown` cho kéo bằng header; `didMove` lưu vị trí bất kể chế độ click xuyên qua; con trỏ `openHand` trên header. `TwoPaneView` thêm dải header (icon tay nắm + "Grammar", nền mờ tối thiểu 60%). Cập nhật README. Kiểm tra bằng tay: khi click xuyên qua đang bật, kéo header thì panel di chuyển và app đang gõ giữ focus; click ngay dưới header thì đi xuống app phía sau; ở độ mờ 0% header vẫn thấy và kéo được; khởi động lại app thì panel vẫn ở chỗ đã kéo.

## 5. Tài liệu và kiểm tra tích hợp

- [x] 5.1 Cập nhật `README.md`: panel chỉ để xem và click xuyên qua, cách mở Cài đặt, `⌃⌥C`, bỏ phần nhập tay vào panel, ghi rủi ro khi quyền Accessibility bị chặn. Kiểm tra: không còn chỗ nào trong README nhắc tới gõ hoặc dán vào panel (`grep -n "dán" README.md`).
- [x] 5.2 Chạy toàn bộ unit test (`xcodebuild -project GrammarApp.xcodeproj -scheme GrammarApp -derivedDataPath build test`) và build Release. Kiểm tra: tất cả pass và build thành công.
- [x] 5.3 Test tay end-to-end: gõ câu sai trong Slack và Chrome khi panel đè lên vùng đang làm việc. Kiểm tra: panel vẫn gạch chân và hiện câu sửa, click và gõ ở app phía sau không bị cản, panel không lấy focus, cài đặt còn nguyên sau khi khởi động lại app.

## Workflow follow-up

- Archive change bằng `/opsx:archive` sau khi test tay đạt.
