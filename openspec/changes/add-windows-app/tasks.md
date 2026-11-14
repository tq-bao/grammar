# Tasks

Ghi chú: Nhóm 1–7 làm và kiểm chứng hoàn toàn trên Mac. Code chạy được trên Windows (UIA, panel, khay) được kiểm chứng trên Mac bằng build thành công, kèm một dòng trong `windows/docs/manual-test.md`. Nhóm 8 cần máy Windows thật.

## 1. Khung solution

- [x] 1.1 Cài .NET 10 SDK trên Mac (`brew install --cask dotnet-sdk` hoặc trình cài của Microsoft). Kiểm tra: `dotnet --version` in ra 10.x.
- [x] 1.2 Tạo `windows/Grammar.sln` với các project `Grammar.Core`, `Grammar.Engine`, `Grammar.App` (WPF, `net10.0-windows`, `UseWPF` + `UseWindowsForms`), `Grammar.Bench`, `Grammar.Probe`, `Grammar.Core.Tests`, `Grammar.Engine.Tests`. Thêm `Directory.Build.props` (Nullable, TreatWarningsAsErrors, `EnableWindowsTargeting=true`), `Directory.Packages.props` ghim phiên bản NuGet, và `windows/.gitignore`. Kiểm tra: `dotnet build windows/Grammar.sln` thành công trên Mac.

## 2. Grammar.Core: diff, normalizer, guard

- [x] 2.1 Port `Tokenizer` (offset UTF-16, `Rune.IsLetter`/`IsDigit`, nháy và gạch nối ở giữa từ) và `WordDiff`. Kiểm tra: port toàn bộ `DiffTests.swift` sang xUnit, thêm case có emoji và ký tự ngoài BMP. `dotnet test` pass.
- [x] 2.2 Port `CorrectionNormalizer` và `DiffHighlighter`. Kiểm tra: port `CorrectionNormalizerTests.swift` và `DiffHighlighterTests.swift`, pass.
- [x] 2.3 Viết `SentenceSegmenter` theo design §4 (dấu kết câu, xuống dòng, từ viết tắt, số thập phân, tên miền). Kiểm tra: test riêng cho từng quy tắc, và các câu nhiều câu trong `PipelineTests.swift`.
- [x] 2.4 Port `EditGuard` dùng `SentenceSegmenter` để đếm câu. Kiểm tra: port các test EditGuard, bao gồm scenario "I'm collect more envidences" và "She dont has any monies" của spec `grammar-correction`.
- [x] 2.5 Port `OutputSanitizer` và `GrammarPrompt`, copy nguyên văn system prompt và ví dụ mẫu từ `GrammarKit/Engine/GrammarPrompt.swift`. Kiểm tra: test sanitizer được port. Thêm một test đọc `GrammarPrompt.swift` trong repo và so khớp từng chuỗi prompt với bản C#, để hai bản không lệch nhau.

## 3. Grammar.Core: ngôn ngữ, pipeline, panel

- [x] 3.1 Viết `LanguageDetector` và hai danh sách từ (resource nhúng: từ tiếng Anh thông dụng có từ viết tắt chat, và âm tiết tiếng Việt không dấu) theo design §4. Port `LanguageGate`. Kiểm tra:
  - Test cho mọi scenario của requirement "Chỉ kiểm tra câu tiếng Anh".
  - Toàn bộ câu trong `GrammarAppTests/Fixtures/golden.json` được nhận là tiếng Anh.
  - Khoảng 30 câu tiếng Việt có dấu và không dấu bị nhận là không phải tiếng Anh.
- [x] 3.2 Port `SentenceExtractor` và `CaretContext`. Kiểm tra: port `CaretContextTests.swift` và các test extractor trong `PipelineTests.swift` (câu chứa con trỏ, không có con trỏ thì lấy câu cuối, bỏ `U+FFFC`).
- [x] 3.3 Port `ResultCache` và `CheckCoordinator` (debounce 700 ms qua `TimeProvider`, huỷ bằng `CancellationToken`, enum trạng thái, `INotifyPropertyChanged`), cùng `IGrammarEngine` và một engine giả. Kiểm tra: port các test coordinator trong `PipelineTests.swift` (gõ liên tục thì không gọi engine, câu cũ không ghi đè câu mới, trúng cache, tạm dừng, lỗi model).
- [x] 3.4 Port `PanelLayout` sang hệ toạ độ gốc trên trái, và `PanelSettings` lưu JSON qua interface lưu trữ (mặc định: độ mờ 75%, góc trên phải, độ rộng 460, click xuyên qua bật; giá trị sai thì dùng mặc định; thêm trường model đã chọn). Kiểm tra: port `PanelTests.swift` (đảo trục y), thêm test JSON hỏng hoặc thiếu trường.
- [x] 3.5 Port `GoldenSet` đọc `../GrammarAppTests/Fixtures/golden.json` (đường dẫn tìm theo thư mục gốc repo). Kiểm tra: port `GoldenSetTests.swift`, file parse được và có cả câu sai lẫn câu đúng.

## 4. Grammar.Engine: LLamaSharp

- [x] 4.1 Thêm LLamaSharp cùng các backend Cpu và Vulkan. Viết `ModelLocator` theo thứ tự `GRAMMAR_MODEL_PATH` → model đã chọn → `Models\<default>`, và hàm liệt kê các file `*.gguf`. Kiểm tra: unit test locator với thư mục tạm.
- [x] 4.2 Viết `LlamaGrammarEngine` theo design §5 (greedy, giữ KV cache cho prefix cố định, dừng ở xuống dòng, `maxTokens`, warm-up, `SemaphoreSlim(1)`, lỗi rõ ràng khi thiếu model). Kiểm tra: port `EngineTests.swift` sang `Grammar.Engine.Tests`, tự bỏ qua khi không có model. Trên Mac với model 7B: "They was happy." → "They were happy.".
- [x] 4.3 Viết `BackendSelector`: thử GPU với toàn bộ layer, lỗi thì nạp lại bằng CPU, báo backend đang dùng. Kiểm tra: test ép lỗi GPU (cấu hình giả) thì engine vẫn nạp được bằng CPU và báo `Cpu`. Trên Mac thì báo `Gpu` (Metal).
- [x] 4.4 Viết `Grammar.Bench` (đọc golden set, chạy engine + normalizer + EditGuard, in tỷ lệ giữ nguyên câu đúng, khớp đáp án, bị EditGuard loại, p50/p95, nạp + warm-up, và backend). Kiểm tra: chạy trên Mac với 7B, đạt giữ nguyên ≥ 95% và khớp ≥ 80%. Ghi kết quả vào `docs/model-benchmark.md` ở mục "Bản Windows (LLamaSharp)". Nếu chưa đạt thì dừng lại xử lý trước khi sang nhóm 5.

## 5. Grammar.App: đọc ô bằng UI Automation

- [x] 5.1 Thêm interop UIAutomationClient. Viết `UiaThread`: một thread MTA riêng sở hữu `IUIAutomation`, timeout 250 ms, đẩy kết quả về Dispatcher. Kiểm tra: build trên Mac thành công. Thêm dòng "khởi động không treo, CPU nhàn rỗi gần 0%" vào `windows/docs/manual-test.md`.
- [x] 5.2 Viết `UiaTextCapture` (focus-changed, TextChanged và TextSelectionChanged, poll 500 ms khi hơn 1 giây không có event, đọc theo thứ tự TextPattern2 → TextPattern → ValuePattern, bỏ qua ô mật khẩu, process của chính app, và lỗi truy cập do quyền admin). Gom phần chọn nhánh đọc và lọc vào một hàm thuần để test được. Kiểm tra: unit test cho hàm đó với dữ liệu giả, và build thành công. Thêm vào `manual-test.md` các scenario của spec `text-capture`: Notepad, chuyển ô, ô mật khẩu, app chạy quyền admin, cửa sổ Cài đặt của app.
- [x] 5.3 Viết `Grammar.Probe`: sau 3 giây, in ra ô đang focus (process, ControlType, các pattern hỗ trợ, IsPassword, đoạn văn và vị trí con trỏ theo từng nhánh đọc). Kiểm tra: build thành công. Thêm cách dùng vào `windows/README.md`.

## 6. Grammar.App: panel, khay, cài đặt

- [x] 6.1 Viết `PanelWindow` (không lấy focus bằng `WS_EX_NOACTIVATE`/`MA_NOACTIVATE`, click xuyên qua bằng `WS_EX_TRANSPARENT` cùng timer theo dõi header, kéo bằng `DragMove`, viền nét đứt khi tắt click xuyên qua, `PerMonitorV2`, layout theo vùng làm việc của màn hình, lưu vị trí đã kéo). Kiểm tra: build thành công. Mỗi scenario của các requirement panel trong spec `checker-window` (click xuyên qua, header, bật/tắt, vị trí kéo, góc, DPI) có một dòng trong `manual-test.md`.
- [x] 6.2 Viết `TwoPaneView` dựng `Run` từ `DiffHighlighter` (gạch chân đỏ, ô đỏ ở chỗ thiếu từ, tô xanh, dòng trạng thái gồm cả "Đang nạp model" và lỗi thiếu model ghi rõ tên file). Gom phần chuyển kết quả highlight thành danh sách đoạn có kiểu vào một hàm thuần. Kiểm tra: unit test hàm đó với các ví dụ trong spec ("He have" → "He has", "I going" → "I am going").
- [x] 6.3 Viết `TrayIcon` (Ẩn/Hiện, Tạm dừng/Tiếp tục, Copy câu đã sửa bị vô hiệu khi không có câu sửa, Cài đặt…, Thoát, double-click để ẩn/hiện) và copy clipboard có thử lại. Kiểm tra: build thành công. Thêm các scenario menu và copy vào `manual-test.md`.
- [x] 6.4 Viết `SettingsWindow` (độ mờ, click xuyên qua, góc, Về góc đã chọn, độ rộng, chọn model sẽ nạp lại engine ở nền, dòng "Đang chạy trên: GPU/CPU"). Kiểm tra: build thành công. Thêm các scenario Cài đặt, chọn model và file model bị xoá vào `manual-test.md`.
- [x] 6.5 Viết `App` (một instance qua Mutex cùng EventWaitHandle, `OnExplicitShutdown`, nối capture → coordinator → panel, nạp engine ở nền) và icon `.ico` sinh từ `AppIcon.appiconset`. Kiểm tra: build thành công. Thêm các scenario mở app lần hai và thiếu thư mục model vào `manual-test.md`.

## 7. Đóng gói và tài liệu

- [x] 7.1 Viết `windows/scripts/publish.sh` (self-contained win-x64, Bench và Probe nằm cạnh `Grammar.exe` để dùng chung runtime, nén vào `dist/Grammar-win-x64.zip`) và `windows/scripts/download-model.ps1`. Kiểm tra: chạy `publish.sh` trên Mac tạo được zip, trong đó có `Grammar.exe` và các DLL native của LLamaSharp (cpu, vulkan).
- [x] 7.2 Viết `windows/README.md` gồm: yêu cầu máy (khuyên dùng 16 GB RAM, GPU có Vulkan), giải nén, đặt model, vượt cảnh báo SmartScreen, cách dùng, giới hạn (không phím tắt, không dự phòng, app chạy quyền admin), Grammar.Bench, Grammar.Probe. Thêm vào `README.md` gốc một mục trỏ sang bản Windows và quy tắc "sửa logic thì sửa cả hai bản". Kiểm tra: mọi lệnh trong README chạy được đúng như viết trên Mac (build, test, publish).
- [ ] 7.3 (Tuỳ chọn) Thêm workflow GitHub Actions `windows-latest` chạy `dotnet build` và `dotnet test windows/tests/Grammar.Core.Tests`. Kiểm tra: workflow xanh trên một lần push.
- [x] 7.4 Kiểm tra tích hợp trên Mac: `dotnet test windows/Grammar.sln` pass toàn bộ (test engine chạy với model 7B), `openspec validate add-windows-app --strict` pass, và `xcodebuild ... test` của bản Mac vẫn pass (code Mac không bị ảnh hưởng).

## 8. Kiểm tra trên máy Windows (khi có máy)

- [ ] 8.1 Giải nén zip, đặt model, chạy app. Chạy `Grammar.Bench.exe`. Kiểm tra: app khởi động, có icon khay, không có nút taskbar. Ghi backend (GPU/CPU), p50/p95 và cấu hình máy vào `docs/model-benchmark.md`.
- [ ] 8.2 Spike tương thích: dùng `Grammar.Probe` và gõ thử trong Notepad, Word, Outlook, Chrome (Gmail, Confluence), Edge, Slack, Teams. Kiểm tra: kết quả từng app được ghi vào `docs/app-compatibility.md` ở mục Windows.
- [ ] 8.3 Chạy toàn bộ checklist `windows/docs/manual-test.md`. Kiểm tra: mọi dòng pass, hoặc dòng nào fail đều có ghi chú và issue hay task tiếp theo.

## Workflow follow-up

- Khi archive: sửa tay Purpose của `openspec/specs/text-capture/spec.md` (đang ghi "trên macOS") thành ghi cả hai nền tảng.
- Archive bằng `/opsx:archive` sau khi nhóm 8 xong, hoặc archive sớm hơn nếu chấp nhận nhóm 8 làm thành change riêng.
