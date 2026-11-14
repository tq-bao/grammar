# Tasks

Lệnh test: `xcodebuild -project GrammarApp.xcodeproj -scheme GrammarApp -derivedDataPath build test`.

## 1. Nới gate/guard cho đoạn bôi đen (GrammarKit)

- [x] 1.1 `LanguageGate.evaluate(_:relaxed:)` (mặc định `false`, có thêm overload giữ chữ ký cũ). Khi `relaxed`: dưới 1 từ thì trả `.tooShort`; dưới `minimumWords` từ thì trả `.english`, không gọi bộ nhận diện; từ `minimumWords` trở lên thì nhận diện như cũ. Kiểm tra: test mới trong `PipelineTests` (`"recieve"` relaxed → `.english`; `"recieve"` không relaxed → `.tooShort`; `"Hôm nay tôi đi học muộn."` relaxed → `.notEnglish`; `"   "` relaxed → `.tooShort`). Toàn bộ test `LanguageGate` cũ vẫn pass.
- [x] 1.2 `EditGuard.evaluate(_:relaxed:)` (mặc định `false`). Khi `relaxed` và câu gốc có dưới 3 từ (đếm token có chữ cái như `LanguageGate`) thì bỏ kiểm tra `maxTotalChangeRatio`; giữ nguyên `dissimilarChangeRatio` và kiểm tra số câu. Kiểm tra: test mới (`recieve → receive` relaxed → `.accepted`, không relaxed → `.rewritten`; `go → went` relaxed → `.rewritten`). Test `EditGuard` cũ trong `DiffTests` vẫn pass.

## 2. Nguồn `.selection` và chọn đoạn kiểm tra (GrammarKit)

- [x] 2.1 Thêm `case selection` vào `TextSource`. Trong `CheckCoordinator`: `isPaused` chặn cả `.focusedField` và `.selection`; truyền `relaxed: true` cho gate và guard khi nguồn là `.selection` hoặc `.selectionHotkey`. Kiểm tra: test coordinator với fake engine: `.selection` "recieve" (engine trả "receive") → `.corrected`; `.focusedField` "recieve" → `.idle`, engine không được gọi; `.selectionHotkey` "recieve" → `.corrected`; `.selection` khi paused → không đổi state, engine không được gọi.
- [x] 2.2 Tạo `GrammarKit/Pipeline/CheckTarget.swift` với `resolve(text:cursorUTF16Offset:selection:maxSelectionLength: = 1000) -> (text: String, source: TextSource)?` như design.md mục 2. Kiểm tra: file mới `GrammarAppTests/CheckTargetTests.swift`: có vùng chọn → `(selection đã trim, .selection)`; selection `nil`, `""` hoặc `" \n"` → câu chứa con trỏ với `.focusedField`; selection dài 1001 ký tự UTF-16 → câu chứa con trỏ; selection đúng 1000 ký tự → được giữ; selection gồm hai câu → giữ nguyên cả hai câu; text rỗng và không có selection → `nil`.

## 3. Đọc vùng chọn và nối dây (GrammarApp)

- [x] 3.1 `AXTextCapture`: đổi `onChange` thành `(text, cursor, selection: String?)`. Nhánh text marker đọc chuỗi vùng chọn qua `AXStringForTextMarkerRange` khi start ≠ end marker. Nhánh app gốc dùng `kAXSelectedTextAttribute`, nếu không có thì cắt `AXValue` theo `AXSelectedTextRange` (length > 0, kẹp vào độ dài). Selection chỉ có khoảng trắng thì coi là `nil`. `lastEmitted` so cả `selection`. Ô mật khẩu và chính app này vẫn bị bỏ qua trước mọi lần đọc. Kiểm tra: build app thành công (`xcodebuild ... build`).
- [x] 3.2 `AppModel.start()`: `capture.onChange` gọi `CheckTarget.resolve` rồi `coordinator.submit(target.text, from: target.source)`. Hotkey `⌃⌥G` giữ nguyên. Kiểm tra: build thành công và toàn bộ unit test pass.
- [x] 3.3 Cập nhật tài liệu: README (mục cách dùng) mô tả việc bôi đen để kiểm tra đúng đoạn đó; `windows/README.md` mục "Giữ hai bản khớp nhau" ghi rằng nhánh `relaxed` của `LanguageGate`/`EditGuard` chưa được port sang C#. Kiểm tra: đọc lại hai đoạn đã sửa, đúng với hành vi đã làm.

## 4. Cài đặt và kiểm tra tay

- [ ] 4.1 Chạy `scripts/install.sh`. Kiểm tra: app mới được cài và đang chạy, quyền Accessibility còn nguyên.
- [ ] 4.2 Test tay theo các scenario trong `specs/text-capture/spec.md`:
  - TextEdit: bôi đen "recieve" trong "I will recieve it tomorrow." → panel sửa thành "receive"; click bỏ bôi đen → panel quay về cả câu.
  - Chrome/Confluence: bôi đen một từ rồi kéo rộng sang phải → panel cập nhật theo vùng chọn.
  - Bôi đen hai câu → panel kiểm tra cả hai câu.
  - ⌘A trong tài liệu dài hơn 1000 ký tự → panel kiểm tra câu chứa con trỏ, không treo.
  - Tạm dừng → bôi đen không kích hoạt kiểm tra; `⌃⌥G` vẫn chạy.
  - Gõ bình thường không bôi đen → hành vi như trước.

## Workflow follow-up

- Archive `fix-web-editor-caret-sentence` trước khi archive change này (cùng sửa requirement "Tách câu đang chứa con trỏ").
- Port nhánh `relaxed` và hành vi ưu tiên vùng chọn sang bản Windows trong một change riêng.
