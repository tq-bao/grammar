# Tasks

## 1. Đọc đoạn văn tại con trỏ

- [x] 1.1 Thêm `CaretContext.normalize(paragraph:prefix:)` vào `GrammarKit/Pipeline/CaretContext.swift`. Hàm bỏ `U+FFFC` ở cả đoạn và phần đầu, lấy vị trí con trỏ (UTF-16) bằng độ dài phần đầu, rồi kẹp vào độ dài đoạn. Kiểm tra: unit test với đoạn có `U+FFFC`, phần đầu dài hơn đoạn, phần đầu rỗng, đoạn rỗng, và `"I don’t want to mention"` với con trỏ ở 23 thì `SentenceExtractor` trả về đúng câu đó.
- [x] 1.2 `AXTextCapture`: thêm `paragraphAtCaret(of:)` dùng `AXSelectedTextMarkerRange` → `AXTextMarkerRangeCopyStartMarker` → `AXParagraphTextMarkerRangeForTextMarker` → `AXStringForTextMarkerRange`, và lấy phần đầu đoạn bằng `AXTextMarkerRangeCreate`. Chỉ dùng khi ô có `AXParagraphTextMarkerRangeForTextMarker` (cache theo ô đang focus). `readFocusedElement()` thử cách này trước, không được thì dùng cách cũ. Kiểm tra: build app thành công và toàn bộ unit test pass.

## 2. Chẩn đoán và phát hành

- [x] 2.1 Thêm `scripts/ax-probe.swift`: chỉ đọc, chờ tới khi app đích ở phía trước, rồi in loại ô đang focus, độ dài `AXValue`, `AXSelectedTextRange`, đoạn và câu đọc qua text marker. Ghi cách dùng trong README (mục Phát triển). Kiểm tra: `swift scripts/ax-probe.swift` chạy được và in đúng đoạn đang gõ trong Confluence.
- [x] 2.2 Chạy `scripts/install.sh`. Kiểm tra: app mới được ký bằng "Grammar Local Signing" và đang chạy.
- [x] 2.3 Test tay:
  - Trong Confluence trên Chrome, gõ ở dòng mới bên dưới một đoạn dài có code inline → panel hiện đúng câu đang gõ.
  - Đặt con trỏ vào giữa đoạn phía trên → panel hiện câu chứa con trỏ.
  - TextEdit, Notes và Slack vẫn hoạt động như trước.
