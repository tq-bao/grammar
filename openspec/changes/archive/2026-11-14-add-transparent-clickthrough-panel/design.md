# Design

## Context

Lý do làm và phạm vi xem ở proposal.md, hành vi cần đạt xem ở `specs/checker-window` và `specs/text-capture`.

Hiện trạng:
- `CheckerPanel` là `NSPanel` có titlebar, `.resizable`, nền đục, nhận chuột, tự nhớ vị trí qua `setFrameAutosaveName`.
- `TwoPaneView`:
  - Phần trên là `NSTextView` chỉnh sửa được (`OriginalTextEditor`, phục vụ nhập tay).
  - Phần dưới là `NSTextView` chọn được để copy, kèm nút Copy.
  - Mỗi ô có `.background(.background)` nên nền đục.
- `DiffHighlighter` (GrammarKit) đang trả về `NSAttributedString` hoặc gắn attribute vào `NSMutableAttributedString`.
- `SelectionHotkey` đăng ký một phím Carbon (`⌃⌥G`, `EventHotKeyID.id = 1`) với một event handler riêng.
- App là `LSUIElement`, chỉ có scene `MenuBarExtra`.

## Goals / Non-Goals

**Goals:**
- Panel thành lớp hiển thị thuần: trong suốt theo cài đặt, mặc định không nhận chuột, không bao giờ lấy focus.
- Người dùng tắt được click xuyên qua để kéo panel tới vị trí bất kỳ, và vị trí đó được lưu lại.
- Chiều cao panel tự co theo nội dung, vị trí tính từ góc và độ rộng đã chọn.
- Phần tính khung panel và phần dựng chuỗi tô màu là hàm thuần trong GrammarKit để unit test được.

**Non-Goals:**
- Khi tắt click xuyên qua thì chỉ để kéo panel. Không đổi kích thước bằng chuột (độ rộng chỉnh trong Cài đặt), không chọn chữ, không nhập tay.
- Không làm hiệu ứng blur nền (vibrancy) hay cài đặt cỡ chữ, màu chữ.
- Không hỗ trợ chọn màn hình cụ thể khi có nhiều màn hình: luôn dùng màn hình chính, tức màn hình có menu bar.
- Không đổi pipeline kiểm tra, engine hay model.

## Decisions

### 1. Click xuyên qua bằng `ignoresMouseEvents = true` cho cả panel
- `CheckerPanel` dùng style `[.borderless, .nonactivatingPanel]`, đặt `ignoresMouseEvents = true`, `isOpaque = false`, `backgroundColor = .clear` và `hasShadow = false`. Giữ `level = .floating`, `canJoinAllSpaces` và `fullScreenAuxiliary`.
- `canBecomeKey` trả về `false`, vì panel không cần nhận bàn phím nữa. Như vậy chắc chắn panel không lấy focus, kể cả khi đang tắt click xuyên qua.
- `ignoresMouseEvents` lấy theo `settings.clickThrough` và được đặt lại mỗi khi cài đặt đổi.
- **Phương án đã cân nhắc**:
  - Chỉ cho click xuyên qua ở pixel trong suốt: macOS chỉ cho click đi qua khi pixel trong suốt hoàn toàn, còn nền bán trong suốt vẫn chặn click. Không đáp ứng yêu cầu.
  - Hai cửa sổ (một tay nắm nhận chuột và một lớp nội dung xuyên qua), hoặc giữ phím bổ trợ để thao tác: phức tạp hơn. Sau khi dùng thử, người dùng chọn một công tắc trong Cài đặt (xem §10).

### 2. Nền trong suốt, chữ đục
- `TwoPaneView` vẽ **một** nền chung: `RoundedRectangle(cornerRadius: 12)` tô `Color(nsColor: .windowBackgroundColor).opacity(backgroundOpacity)`. Bỏ nền riêng của từng ô. Chữ, gạch chân và màu tô vẽ phía trên với độ mờ 1.0.
- Chữ có `shadow` nhẹ, màu ngược với màu chữ, bán kính khoảng 1.5, để vẫn đọc được khi độ mờ nền gần 0 trên nền phức tạp.
- **Phương án đã cân nhắc**:
  - `NSVisualEffectView` hoặc `.material`: làm nhoè nội dung phía sau, trái với mong muốn nhìn rõ nội dung phía sau.
  - `alphaValue` của cửa sổ: làm mờ cả chữ, mà người dùng đã chọn chỉ làm mờ nền.

### 3. Hiển thị bằng SwiftUI `Text(AttributedString)` thay cho `NSTextView`
- Hai phần đều chỉ đọc, nên dùng `Text` để SwiftUI tự tính chiều cao. Nhờ đó panel co giãn theo nội dung mà không phải đo `NSTextView`.
- `DiffHighlighter` đổi sang trả về `AttributedString` với attribute của SwiftUI:
  - `originalText(_:)`: `underlineStyle = Text.LineStyle(pattern: .solid, color: .red)` cho từ sai, kèm `backgroundColor` đỏ nhạt ở khoảng trống thiếu từ.
  - `correctedText(_:)`: `foregroundColor = .green` và đậm cho từ được thêm hoặc thay.
- Vẫn tính vùng tô từ `highlights(for:)` hiện có, nên test vị trí (`DiffHighlights`) giữ nguyên. Bỏ hai API dùng `NSAttributedString`, vì sau khi bỏ `OriginalTextEditor` và `CorrectedTextView` sẽ không còn chỗ nào gọi tới, và cập nhật test tương ứng.

### 4. `PanelSettings` lưu trong `UserDefaults`
- `@MainActor @Observable final class PanelSettings` (trong GrammarApp) có 3 thuộc tính:
  - `backgroundOpacity: Double`: 0…1, mặc định 0.75.
  - `corner: PanelCorner`: `topRight`, `topLeft`, `bottomRight`, `bottomLeft`, mặc định `topRight`.
  - `width: Double`: 320…700, mặc định 460.
- Mỗi lần đổi giá trị thì ghi vào `UserDefaults` với key `panel.backgroundOpacity`, `panel.corner`, `panel.width`. Lúc nạp thì kẹp giá trị vào khoảng hợp lệ. Giá trị không đọc được thì dùng mặc định.
- `PanelCorner` và hàm tính khung nằm trong GrammarKit (`PanelLayout`) để unit test:
  `PanelLayout.frame(corner:size:visibleFrame:margin:) -> CGRect`, với `margin = 20`.

### 5. Chiều cao panel tự co và cập nhật vị trí
- SwiftUI view có `.frame(width: settings.width)` và `.fixedSize(horizontal: false, vertical: true)`.
- `NSHostingView` đặt `sizingOptions = [.intrinsicContentSize]`, override `invalidateIntrinsicContentSize()` để báo panel đặt lại khung: lấy `fittingSize` rồi tính `PanelLayout.frame` theo `NSScreen.screens.first?.visibleFrame`.
- Panel cũng đặt lại khung khi:
  - `settings.corner` hoặc `settings.width` đổi (dùng `withObservationTracking` lặp lại trong `AppModel`).
  - Cấu hình màn hình đổi (`NSApplication.didChangeScreenParametersNotification`).
- Bỏ `setFrameAutosaveName`, vì vị trí giờ do cài đặt quyết định.

### 6. Màn hình Cài đặt bằng scene `Settings` của SwiftUI
- `GrammarApp` thêm `Settings { SettingsView(settings:) }`. Nội dung gồm:
  - `Slider` độ mờ nền 0–100%, có hiện số %.
  - `Picker` chọn góc (dạng segmented hoặc lưới 2×2).
  - `Slider` độ rộng 320–700 pt.
  - Nút "Khôi phục mặc định".
- Menu bar có mục "Cài đặt…", dùng `@Environment(\.openSettings)` và phím tắt ⌘,. Trước khi mở thì gọi `NSApp.activate()`, vì app `LSUIElement` không tự đưa cửa sổ lên trước.
- Cửa sổ Cài đặt là của chính app nên `AXTextCapture` bỏ qua, vì đã loại `ownPID`. Không cần sửa gì thêm.

### 7. Phím tắt toàn cục dùng chung: `GlobalHotkeys`
- Tách phần Carbon trong `SelectionHotkey` ra thành `GlobalHotkeys`. Lớp này cài **một** event handler, đăng ký nhiều phím, và phân phối theo `EventHotKeyID.id`:
  - `1` là `⌃⌥G` (kiểm tra đoạn bôi đen).
  - `2` là `⌃⌥C` (copy câu sửa).
- `SelectionHotkey` chỉ còn lo phần giả lập ⌘C và lưu, khôi phục clipboard.
- `AppModel.copyCorrection()` chỉ ghi clipboard khi `coordinator.state` là `.corrected(diff)`, và ghi `diff.corrected`. Menu dùng `canCopyCorrection` để vô hiệu mục "Copy câu đã sửa" khi không có câu sửa.

### 8. Quyền Accessibility
- `PermissionView` trên panel giữ phần chữ hướng dẫn và bỏ nút, vì không bấm được. Chữ hướng dẫn trỏ tới mục menu bar.
- `MenuBarContent` hiện mục "Cấp quyền Accessibility…" khi `!model.isTrusted`. Mục này gọi `openAccessibilitySettings()` (đã có).

### 9. GrammarKit
- `TextSource.manual` được giữ lại. Nó vô hại và test của `CheckCoordinator` vẫn dùng. Không đổi logic.

### 10. Bật/tắt click xuyên qua và kéo panel
- `PanelSettings` có thêm 2 thuộc tính:
  - `clickThrough: Bool`: mặc định `true`, key `panel.clickThrough`.
  - `customTopLeft: CGPoint?`: góc trên trái của panel do người dùng kéo, theo toạ độ AppKit. Lưu dạng mảng `[x, y]` ở key `panel.customTopLeft`. Giá trị `nil` thì xoá key.
- Đổi `corner` (chọn góc trong Cài đặt) hoặc gọi `resetToDefaults()` thì đặt `customTopLeft = nil`. Thêm `resetPosition()` cho nút "Về góc đã chọn".
- **Kéo panel**: khi `clickThrough == false`, `AutoSizingHostingView.hitTest` trả về chính nó, và `mouseDown` gọi `window.performDrag(with:)`. Cách này kéo được cửa sổ borderless mà không cần titlebar, và không kích hoạt app (panel vẫn nonactivating, `canBecomeKey = false`). Khi `clickThrough == true`, `hitTest` trả về `nil`.
- **Lưu vị trí**: panel nghe `NSWindow.didMoveNotification`. Mọi lần di chuyển không do `relayout()` gây ra (lúc `relayout()` gọi `setFrame` thì có cờ `isApplyingLayout`) được coi là người dùng kéo, và lưu `customTopLeft = (frame.minX, frame.maxY)`.
- **Đặt khung**: nếu có `customTopLeft` thì dùng `PanelLayout.frame(topLeft:size:visibleFrame:)`. Panel giữ góc trên trái và co chiều cao xuống dưới, rồi được kẹp vào `visibleFrame` của màn hình chứa điểm đó (nếu không thấy màn hình nào thì dùng màn hình chính). Nếu không có `customTopLeft` thì dùng góc như §5.
- **Báo hiệu kéo được**: khi tắt click xuyên qua, `TwoPaneView` vẽ viền `accentColor` quanh nền bo góc.
- **Phương án đã cân nhắc**:
  - `isMovableByWindowBackground`: `NSHostingView` có thể nuốt `mouseDown`, nên kéo không ổn định.
  - `WindowDragGesture` của SwiftUI: dành cho cửa sổ do SwiftUI quản lý, còn panel này là `NSPanel` tự tạo.

### 11. Header luôn kéo được trong một cửa sổ duy nhất
- `ignoresMouseEvents` áp dụng cho cả cửa sổ, nên app cần biết chuột đang ở đâu để bật hoặc tắt nó:
  - `NSEvent.addGlobalMonitorForEvents([.mouseMoved, .leftMouseDragged, .leftMouseUp])`: bắt chuột di chuyển trên các app khác. Lúc panel đang bỏ qua chuột thì sự kiện thuộc về app phía sau, nên monitor này vẫn nhận được. Monitor chuột không cần quyền gì thêm.
  - Một `NSTrackingArea` (`.activeAlways`, `.mouseMoved`, `.mouseEnteredAndExited`, `.cursorUpdate`, `.inVisibleRect`) trên hosting view: bắt lúc chuột rời header khi panel đang nhận chuột.
  - Mỗi lần nhận sự kiện thì tính `overHeader = PanelLayout.headerRect(in: frame).contains(NSEvent.mouseLocation)` rồi đặt `ignoresMouseEvents = settings.clickThrough && !overHeader`.
- `PanelLayout.headerHeight = 24` và `PanelLayout.headerRect(in:)` (dải trên cùng của khung panel) là hàm thuần trong GrammarKit để unit test.
- `AutoSizingHostingView.hitTest` trả về chính nó khi panel kéo được toàn bộ, hoặc khi điểm nằm trong dải header. `mouseDown` gọi `performDrag` trong hai trường hợp đó. Con trỏ đổi thành `openHand` qua `cursorUpdate`.
- Lưu vị trí: `didMove` lưu `customTopLeft` cho mọi lần di chuyển không do `relayout()` gây ra, bất kể chế độ click xuyên qua.
- Header nằm trong `TwoPaneView`: dải cao đúng `PanelLayout.headerHeight` ở trên cùng. Nền header là `UnevenRoundedRectangle` (chỉ bo hai góc trên) với độ mờ `max(backgroundOpacity, 0.6)`, chứa icon `line.3.horizontal` và chữ "Grammar".
- **Phương án đã cân nhắc**:
  - Hai cửa sổ: header là cửa sổ cha nhận chuột, nội dung là cửa sổ con xuyên qua và đi theo cha. Không phải theo dõi chuột, nhưng phải đồng bộ kích thước, độ rộng và level giữa hai cửa sổ, phức tạp hơn.
  - Timer hỏi vị trí chuột khoảng 20 lần/giây: đơn giản nhưng đánh thức CPU liên tục và tốn pin. Theo dõi theo sự kiện tốt hơn.

## Risks / Trade-offs

- [Chuột lướt nhanh từ header xuống phần nội dung mà tracking area không kịp báo, nên phần nội dung nhận một click] → Cập nhật lại ở cả `mouseMoved` lẫn `mouseDown`. Nếu `mouseDown` rơi vào ngoài header lúc đang bật click xuyên qua thì bỏ qua click đó và đặt lại `ignoresMouseEvents = true`.
- [Người dùng quên bật lại click xuyên qua, panel cản click] → Có viền báo hiệu khi đang tắt. README hướng dẫn tắt để kéo, kéo xong thì bật lại.
- [Vị trí đã kéo nằm ở màn hình phụ, sau đó màn hình phụ bị rút ra] → Nếu không thấy màn hình nào chứa điểm đã lưu thì kẹp vào màn hình chính.
- [Độ mờ 0% trên nền nhiều chữ khó đọc] → Thêm shadow cho chữ. Người dùng tự chỉnh lại trong Cài đặt.
- [Đã bỏ nhập tay, nên khi quyền Accessibility bị chặn thì app không nhận được câu nào] → Ghi trong README và proposal (Impact). Hiện quyền đang hoạt động trên máy người dùng.
- [`⌃⌥C` trùng phím tắt của app khác] → Carbon hotkey ưu tiên app đăng ký trước. Nếu bị trùng thì ghi lại để xử lý sau, vì đổi phím tắt nằm ngoài phạm vi change này.
- [`Text` của SwiftUI không hỗ trợ màu gạch chân giống hệt AppKit] → `Text.LineStyle(color:)` có hỗ trợ màu gạch chân. Kiểm tra bằng mắt khi test tay.
- [Panel tính sai vị trí khi Dock ẩn hoặc hiện, hoặc khi đổi màn hình] → Dùng `visibleFrame` và lắng nghe `didChangeScreenParametersNotification`.

## Migration Plan

- Cài đặt mới có giá trị mặc định nên không cần chuyển dữ liệu.
- Bỏ key autosave cũ `NSWindow Frame GrammarCheckerPanel` trong `UserDefaults` (xoá khi khởi động để khỏi rác).
- Rollback: quay về commit trước change này. Không có dữ liệu nào cần khôi phục.
