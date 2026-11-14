# Tasks

Ghi chú: change này chỉ sửa code macOS. Không sửa `GrammarKit/Engine/GrammarPrompt.swift`, vì change `add-windows-app` có test so khớp file này với bản C#. Lệnh test dùng chung: `xcodegen generate && xcodebuild test -project GrammarApp.xcodeproj -scheme GrammarApp -derivedDataPath build`.

## 1. Cài đặt bật/tắt Dịch

- [x] 1.1 Thêm `translationEnabled` vào `GrammarKit/Panel/PanelSettings.swift`: key `Key.translationEnabled = "translation.enabled"`, mặc định `defaultTranslationEnabled = false`, lưu `UserDefaults` theo mẫu `clickThrough`, và đưa vào `resetToDefaults()`. Kiểm tra: thêm test trong `GrammarAppTests/PanelTests.swift` (mặc định `false`, lưu rồi đọc lại bằng instance mới, giá trị sai kiểu thì về `false`, `resetToDefaults` về `false`). Test pass.

## 2. Engine dịch

- [x] 2.1 Tạo `GrammarKit/Engine/TranslationPrompt.swift` theo design §4: system prompt dịch Anh sang Việt và 4–5 ví dụ (câu thường, câu viết tắt chat, câu có tên riêng/thuật ngữ, câu hỏi). Hàm `messages(for:)` trả `[GrammarPrompt.Message]`. Kiểm tra: test trong `EngineTests.swift` cho thấy message đầu là system, message cuối là câu cần dịch, và số message bằng `1 + 2 × số ví dụ + 1`.
- [x] 2.2 Thêm `OutputSanitizer.cleanTranslation(_:)` và `GrammarEngineError.emptyTranslation` (có `errorDescription` tiếng Việt) theo design §5. Kiểm tra: test bỏ tiền tố "Translation:"/"Bản dịch:", bỏ ngoặc kép bao ngoài, lấy dòng đầu không rỗng, output rỗng hoặc chỉ có khoảng trắng thì ném `.emptyTranslation`.
- [x] 2.3 Thêm protocol `TranslationEngine: Sendable { func translate(_ sentence: String) async throws -> String }` vào `GrammarKit/Engine/GrammarEngine.swift`. Kiểm tra: build pass.
- [x] 2.4 Refactor `LlamaGrammarEngine`, gom trạng thái theo context vào một `Session` private theo design §3, và cho `prefill`/`decode`/`fixedPrefixTokens`/vòng sinh token nhận session. Chưa thêm tính năng. Kiểm tra: `LlamaEngineIntegrationTests` vẫn pass, và `GrammarBench --model ...7B...` cho cùng tỉ lệ giữ/khớp với bảng trong `docs/model-benchmark.md`, p95 không tăng quá 10%.
- [x] 2.5 Cho `LlamaGrammarEngine` conform `TranslationEngine`: tạo session dịch một cách lười (context thứ hai từ cùng model, sampler greedy riêng), `maxTokens = số token câu × 4 + 32`, và làm sạch output bằng `cleanTranslation`. Kiểm tra: thêm integration test (bỏ qua khi không có model). `translate("I have finished the report.")` trả chuỗi không rỗng, có ký tự tiếng Việt có dấu. Ngay sau đó `correct("He have two cats.")` vẫn trả "He has two cats.".

- [x] 2.6 Cấm token chữ Trung/Nhật/Hàn trong sampler của phiên dịch (design §5b): quét vocab một lần khi tạo phiên, dùng `llama_sampler_init_logit_bias` với bias −∞. Kiểm tra: unit test cho hàm nhận diện ký tự CJK (chữ Hán, Kana, Hangul thì đúng, chữ Việt có dấu thì sai). `GrammarBench --translate` không còn bản dịch nào có ký tự CJK.

## 3. Pipeline: trạng thái dịch trong CheckCoordinator

- [x] 3.1 Thêm `TranslationState` (`hidden`, `translating`, `done(String)`, `failed(String)`), các thuộc tính `translation` và `isTranslationEnabled`, tham số `translator` cho `init`/`setEngine`, cùng `translationTask` và `translationCache`, theo design §6–7. Dịch câu sửa khi `.corrected`, dịch câu gốc khi `.ok`. Mọi trạng thái khác thì `.hidden`. `submit` và việc tắt Dịch huỷ task. Guard câu cũ trước khi ghi kết quả. `waitForPendingCheck()` đợi cả task dịch. Kiểm tra: build pass, và các test cũ trong `PipelineTests.swift` vẫn pass.
- [x] 3.2 Viết test cho coordinator trong `GrammarAppTests/PipelineTests.swift`, dùng `FakeTranslator` (actor, có bảng trả lời, độ trễ, đếm số lần gọi, và chế độ ném lỗi). Mỗi test ứng với một scenario của spec `translation`:
  - tắt thì `.hidden` và không gọi `translate`;
  - `.corrected` dịch câu sửa;
  - `.ok` dịch câu gốc;
  - `notEnglish` và `uncertain` cho ra `.hidden`;
  - câu mới khi đang dịch thì kết quả cũ không bao giờ ghi vào `translation`;
  - quay lại câu đã dịch thì số lần gọi không tăng;
  - bật giữa chừng thì dịch câu đang hiện;
  - tắt khi đang dịch thì `.hidden`;
  - translator ném lỗi thì `.failed`, còn `state` vẫn là `.corrected`.

  Kiểm tra: tất cả pass.

## 4. App: Cài đặt, panel, nối dây

- [x] 4.1 Trong `GrammarApp/App/AppModel.swift`:
  - truyền engine vào `setEngine(engine, translator: engine)`;
  - gán `coordinator.isTranslationEnabled` từ `settings.translationEnabled` lúc `start()`;
  - theo dõi thay đổi bằng `withObservationTracking` (thêm vào `observeLayoutSettings` hoặc một hàm riêng) và gọi `panel?.scheduleRelayout()`.

  Kiểm tra: build pass. Đổi công tắc trong Cài đặt thì `coordinator.isTranslationEnabled` đổi theo (xem bằng test tay ở 5.2).
- [x] 4.2 Thêm vào `GrammarApp/UI/SettingsView.swift` một `Section("Dịch")`, gồm `Toggle` "Dịch sang tiếng Việt" và dòng mô tả. Kiểm tra: mở Cài đặt thấy công tắc tắt. Bật, thoát app rồi mở lại, công tắc vẫn bật.
- [x] 4.3 Thêm section "Bản dịch" vào `GrammarApp/UI/TwoPaneView.swift`, dưới "Câu đã sửa": `Divider`, tiêu đề "Bản dịch (tham khảo)", và nội dung theo `coordinator.translation` (`translating` hiện placeholder "Đang dịch…", `done` hiện chữ thường, `failed` hiện chữ đỏ). Section ẩn khi tắt Dịch hoặc khi `.hidden`. Kiểm tra: các bước trong 5.2.
- [x] 4.4 Cập nhật `README.md`: thêm vào hàng Cài đặt trong bảng "Cách dùng" và ghi chú rằng Dịch chạy offline, mặc định tắt, chỉ có trên macOS. Kiểm tra: đọc lại thấy khớp với spec `translation`.

## 5. Đo đạc và kiểm tra tích hợp

- [x] 5.1 Thêm cờ `--translate` vào `GrammarBench/main.swift`. Cờ này dịch khoảng 15 câu mẫu (có một câu dài khoảng 40 từ, một câu hỏi, một câu viết tắt chat), in từng bản dịch, p50/p95 của bước dịch, và p95 của bước sửa khi chạy xen kẽ sửa–dịch. Ghi kết quả vào mục "Dịch" mới trong `docs/model-benchmark.md`. Kiểm tra: p95 của bước sửa khi xen kẽ vẫn ≤ 1.5 s, và đọc qua các bản dịch thấy đúng nghĩa. Câu hỏi được dịch, không bị trả lời.
- [ ] 5.2 Test tay trên app cài bằng `./scripts/install.sh`, theo các scenario của spec `translation`:
  - bật Dịch, gõ "She go to school yesterday" trong Notes: câu sửa hiện trước, rồi "Đang dịch…", rồi bản dịch;
  - câu đúng có bản dịch;
  - câu tiếng Việt không có section;
  - gõ tiếp khi đang dịch thì không thấy bản dịch cũ;
  - tắt công tắc thì section biến mất và panel co lại;
  - tắt Wi-Fi vẫn dịch được;
  - khởi động lại app, cài đặt vẫn giữ.

  Kiểm tra: mọi bước đạt. Bước nào không đạt thì ghi lại và thêm task sửa.

## Workflow follow-up

- Archive change sau khi review xong (`/opsx:archive`). Archive change này **sau** `add-windows-app` hoặc độc lập với nó, vì hai change sửa hai requirement khác nhau trong `checker-window`.
- Port tính năng sang bản Windows trong một change riêng. Khi đó bỏ requirement "Chỉ có trên macOS".
