# Design

## Context

Luồng hiện tại (macOS):

```
AXTextCapture.readFocusedElement()
   -> onChange(text, cursor)          cursor = ĐIỂM ĐẦU vùng chọn, độ dài bị bỏ
AppModel
   -> SentenceExtractor.sentence(text, cursor)
   -> CheckCoordinator.submit(sentence, from: .focusedField)   debounce 700 ms
CheckCoordinator.run
   -> LanguageGate (>= 3 từ, nhận diện tiếng Anh) -> cache -> engine -> EditGuard
```

- `AXTextCapture` đã đăng ký `kAXSelectedTextChangedNotification`, và poll mỗi 500 ms với app không gửi notification.
- Có hai cách đọc: text marker cho web/Electron (`paragraphAtCaret`, đọc `AXSelectedTextMarkerRange` nhưng chỉ dùng start marker), và `AXValue` + `AXSelectedTextRange` cho app gốc (chỉ dùng `location`).
- `readFocusedElement` bỏ qua lần đọc trùng `(text, cursor)` với lần trước. Vì vậy kéo rộng vùng chọn về bên phải (start không đổi) không phát ra gì.
- Phím tắt `⌃⌥G` gửi `.selectionHotkey` với `immediately: true`, đi qua cùng gate/guard nên đoạn 1 từ cũng bị chặn.
- Engine có context 2048 token và prompt cố định khoảng vài trăm token.

## Goals / Non-Goals

**Goals:**
- Logic chọn "đoạn bôi đen hay câu ở con trỏ" nằm trong GrammarKit, là hàm thuần để unit test được.
- Nới gate/guard chỉ cho nguồn bôi đen. Hành vi khi gõ bình thường giữ nguyên từng chi tiết.

**Non-Goals:**
- Không đổi prompt/few-shot (giữ kết quả benchmark).
- Không làm bản Windows (`UiaTextCapture`, `FocusedFieldReader`).
- Không mở rộng phạm vi đọc. Bôi đen ở chỗ mà cơ chế theo dõi vốn không đọc tới thì vẫn không đọc.

## Decisions

### 1. Capture trả thêm `selection: String?`, không trả range
`onChange` đổi thành `(text, cursor, selection)`, trong đó `selection` là chuỗi đã đọc sẵn (nil nếu vùng chọn rỗng).
- Nhánh text marker: nếu start marker ≠ end marker của `AXSelectedTextMarkerRange` thì đọc chuỗi bằng `AXStringForTextMarkerRange` trên chính range đó. Hàm `string(for:in:)` đã có sẵn.
- Nhánh app gốc: ưu tiên `kAXSelectedTextAttribute`. Nếu thiếu thì cắt `AXValue` theo `AXSelectedTextRange` khi `length > 0` (kẹp vào độ dài chuỗi).
- *Phương án khác*: trả `(location, length)` rồi cắt trong GrammarKit. Không chọn vì ở nhánh text marker, range của vùng chọn không cùng hệ toạ độ với đoạn văn khi vùng chọn vượt ra ngoài đoạn chứa con trỏ (bôi nhiều đoạn). Đọc thẳng chuỗi thì đúng trong mọi trường hợp.
- Dedupe `lastEmitted` so cả `selection`.

### 2. `CheckTarget.resolve` trong GrammarKit
`resolve(text:cursorUTF16Offset:selection:maxSelectionLength:) -> (text, source)?`:
- Nếu `selection` sau khi trim không rỗng và độ dài UTF-16 ≤ `maxSelectionLength` (mặc định 1000) thì trả `(selection đã trim, .selection)`.
- Ngược lại trả `SentenceExtractor.sentence(...)` với `.focusedField`. Trả `nil` nếu không có câu, giống hiện tại.
- Lý do chọn 1000 ký tự: khoảng 250 token vào và 250 token ra, cộng prompt vẫn vừa 2048 token và chạy vài giây. Vượt ngưỡng thì gần như chắc là ⌘A hoặc bôi đen để copy, không phải để kiểm tra.
- *Phương án khác*: cắt bớt vùng chọn dài. Không chọn vì kết quả sửa một đoạn bị cắt dễ gây hiểu nhầm.

### 3. `TextSource.selection` mới
- Tách khỏi `.selectionHotkey` vì tạm dừng chặn `.selection` (đến từ cơ chế theo dõi) nhưng không chặn phím tắt. `isPaused` kiểm tra `source == .focusedField || source == .selection`.
- Coordinator có `isSelection(source)` đúng cho `.selection` và `.selectionHotkey`, dùng để nới gate/guard.

### 4. Nới gate/guard bằng tham số, không đổi giá trị mặc định
- `LanguageGate.evaluate(_:relaxed:)`: khi `relaxed` thì `minimumWords = 1`. Dưới `self.minimumWords` (3) từ thì trả `.english` luôn, bỏ nhận diện vì nhận diện một hai từ không đáng tin. Từ 3 từ trở lên thì nhận diện như cũ.
- `EditGuard.evaluate(_:relaxed:)`: khi `relaxed` và câu gốc có dưới 3 từ thì bỏ kiểm tra `maxTotalChangeRatio`. Vẫn giữ `dissimilarChangeRatio` và kiểm tra số câu. Đếm từ theo cùng cách với `LanguageGate` (token có chữ cái).
- *Phương án khác*: tạo sẵn hai instance gate/guard với tham số khác nhau. Không chọn vì quy tắc "dưới 3 từ thì bỏ nhận diện" không diễn đạt được bằng tham số khởi tạo hiện có.

Về quy định "sửa EditGuard/bộ lọc ngôn ngữ thì sửa cả bản C#" (windows/README.md, mục "Giữ hai bản khớp nhau"): đường mặc định (`relaxed: false`) giữ nguyên từng chi tiết, nên các parity test và fixture `language-oracle.json` không đổi. Nhánh `relaxed` chỉ được gọi từ nguồn bôi đen, nên sẽ port sang C# cùng change Windows sau. Thêm ghi chú vào mục đó của windows/README.md để không bị quên.

### 5. Cache dùng chung
Key vẫn là text. Với cùng một chuỗi, kết quả `.rewritten` chỉ có thể khác giữa hai nguồn khi chuỗi dưới 3 từ. Nhưng chuỗi dưới 3 từ từ `.focusedField` bị gate chặn trước khi tới cache, nên không bao giờ đọc hay ghi cache. Không có xung đột.

## Risks / Trade-offs

- [Model xử lý 1 từ kém, ví dụ trả cả câu giải thích] → `OutputSanitizer` và `EditGuard` (kiểm tra số câu, tỉ lệ từ khác hẳn) đã chặn phần lớn. Thử tay với vài từ sai chính tả phổ biến; nếu kém thì mở change riêng cho prompt.
- [Bôi đen để copy/xoá, không định kiểm tra, làm panel đổi nội dung] → Chấp nhận, vì đúng yêu cầu "ưu tiên đoạn bôi đen". Debounce 700 ms hạn chế việc chạy model khi đang kéo chuột.
- [App gốc không có `kAXSelectedTextAttribute` và `AXValue` lệch với range (như Chrome trước đây)] → Các ô đó thường hỗ trợ text marker nên đi nhánh text marker trước.
- [Xung đột với change `fix-web-editor-caret-sentence` chưa archive, cùng sửa requirement "Tách câu đang chứa con trỏ"] → Delta của change này đã gồm cả nội dung và scenario mà change kia thêm vào. Cần archive `fix-web-editor-caret-sentence` **trước** change này.
- [Windows chưa có hành vi mới] → Ghi trong proposal; requirement mới ghi rõ "Trên macOS".
