# Proposal

## Why

Khi gõ trong trình soạn thảo web có định dạng, ví dụ trang Confluence trên Chrome, app kiểm tra nhầm một đoạn văn khác thay vì câu đang gõ. Dò trực tiếp Chrome cho thấy nguyên nhân:
- Ô đang focus là toàn bộ trình soạn thảo, `AXValue` dài hơn 10,000 ký tự.
- Vị trí con trỏ (`AXSelectedTextRange`) bị lệch khoảng 50 ký tự so với chuỗi `AXValue`. Chrome tính vị trí con trỏ và dựng chuỗi theo hai cách khác nhau ở code inline và các phần tử lồng nhau. Sai lệch dồn lại theo độ dài trang, nên vị trí con trỏ rơi vào đoạn phía trên.
- API text marker của Chrome (`AXParagraphTextMarkerRangeForTextMarker`) lại trả về đúng đoạn đang gõ và đúng vị trí con trỏ trong đoạn.

## What Changes

- Với ô hỗ trợ text marker (Chrome, Safari/WebKit, app Electron như Slack và Teams), app đọc **đoạn văn chứa con trỏ** và **vị trí con trỏ trong đoạn** qua text marker, rồi tách câu chứa con trỏ như trước.
- Ô không hỗ trợ text marker (TextEdit, Notes và các app gốc khác) vẫn đọc như hiện tại.
- Ký tự thay thế phần tử nhúng (`U+FFFC`, ví dụ ảnh hay mention) được bỏ đi mà vị trí con trỏ vẫn khớp.
- Thêm script chẩn đoán chỉ đọc `scripts/ax-probe.swift`, in ra những gì một app trả về qua Accessibility, để kiểm tra nhanh khi có app khác bị lỗi tương tự.
- Đọc một đoạn văn thay vì cả trang sau mỗi phím gõ cũng giúp nhẹ hơn với trang dài.

## Capabilities

### New Capabilities
<!-- Không có. -->

### Modified Capabilities
- `text-capture`: requirement "Tách câu đang chứa con trỏ" thêm scenario cho trình soạn thảo web có định dạng (nhiều đoạn, code inline).

## Impact

- **Code**:
  - `GrammarApp/Capture/AXTextCapture.swift`: đọc đoạn văn qua text marker, cách cũ làm dự phòng.
  - **Mới** `GrammarKit/Pipeline/CaretContext.swift`: chuẩn hoá đoạn văn và vị trí con trỏ, có unit test.
  - **Mới** `scripts/ax-probe.swift`.
- **Không đổi**: pipeline kiểm tra, engine, panel.
- **Change `add-windows-app`** (đang dở) không bị ảnh hưởng, vì không sửa requirement này.
