# Design

## Context

Lý do và phạm vi: xem proposal.md. Hành vi: xem delta spec trong `specs/`.

Hiện trạng code macOS liên quan tới việc port:
- `GrammarKit/` gần như là Swift thuần, khoảng 1.300 dòng. Có ba chỗ phụ thuộc Apple:
  - `NLTokenizer(.sentence)` trong `SentenceExtractor` và `EditGuard` (đếm số câu).
  - `NLLanguageRecognizer` trong `LanguageGate`.
  - `UserDefaults` và `@Observable` trong `PanelSettings`/`CheckCoordinator`.
- `PanelLayout` tính toạ độ theo AppKit, gốc ở góc dưới trái. Windows/WPF dùng gốc ở góc trên trái.
- `GrammarApp/` (Accessibility, NSPanel, SwiftUI, Carbon hotkey) gắn chặt với macOS, phải viết lại.
- Engine gọi thẳng C API của llama.cpp tag `b12376`. Engine giữ KV cache cho phần prompt cố định, nhờ vậy p95 của model 7B giảm từ 1.66 giây xuống 0.45 giây.

Ràng buộc:
- Chỉ có máy Mac (Apple Silicon) để phát triển. Hiện chưa có máy Windows, và chưa biết cấu hình máy đích.
- Máy đích là máy cá nhân, có quyền admin. Không cần ký code.

## Goals / Non-Goals

**Goals:**
- Mọi thứ không gắn với Windows (logic, engine, golden set) đều build và test được trên Mac.
- App WPF build và đóng gói được trên Mac (cross-compile win-x64).
- Thứ tự tầng và tên khái niệm giống bản Mac (capture → pipeline → engine → panel), để đọc và sửa song song hai bản cho dễ.

**Non-Goals:**
- Không đổi code macOS, không gom hai bản về một codebase.
- Không làm installer, không ký code, không tự cập nhật, không tự khởi động cùng Windows.
- Không build cho win-arm64.
- Không tự bật chế độ screen reader toàn hệ thống để ép Chromium/Electron dựng cây accessibility.

## Decisions

### 1. C# + .NET 10 + WPF, đặt ở `windows/` trong cùng repo
- .NET 10 là bản LTS hiện tại. .NET 8 đã hết hỗ trợ ngày 10/11/2026.
- WPF có sẵn cửa sổ trong suốt (`AllowsTransparency`), vẽ chữ có gạch chân màu (`TextDecoration`), và chạy trên mọi bản Windows 10/11. `NotifyIcon` của WinForms dùng cho icon khay, không cần thêm dependency.
- Đặt `EnableWindowsTargeting=true` để build project WPF trên macOS. Chạy thì phải trên Windows.
- **Đã cân nhắc:**
  - Swift trên Windows: dùng lại được GrammarKit, nhưng UI và UI Automation phải tự gọi Win32/COM từ Swift, công cụ còn non, và không cross-compile được từ Mac.
  - WinUI 3: hiện đại hơn, nhưng cửa sổ trong suốt kiểu click xuyên qua khó làm hơn WPF, và cần Windows App SDK runtime.
  - Viết lại đa nền tảng bằng Rust/Tauri: khối lượng lớn nhất, lại phải thay luôn bản Mac đang chạy tốt.

### 2. Cấu trúc solution

```
windows/
  Grammar.sln, Directory.Build.props (net10.0, Nullable, TreatWarningsAsErrors, EnableWindowsTargeting)
  src/Grammar.Core/      net10.0       Diff, Pipeline, Panel (layout + settings), Engine (interface, prompt,
                                       sanitizer, locator), Text (SentenceSegmenter, LanguageDetector), Evaluation
  src/Grammar.Engine/    net10.0       LlamaGrammarEngine (LLamaSharp), BackendSelector
  src/Grammar.App/       net10.0-windows  WPF: App, Capture (UIA), UI (PanelWindow, TwoPaneView, SettingsWindow), Tray
  src/Grammar.Bench/     net10.0       console, giống GrammarBench
  src/Grammar.Probe/     net10.0-windows  console dò UIA, giống scripts/ax-probe.swift
  tests/Grammar.Core.Tests/    xUnit, chạy trên Mac
  tests/Grammar.Engine.Tests/  xUnit, cần model, tự bỏ qua khi không có
  scripts/publish.sh, scripts/download-model.ps1, docs/manual-test.md
```

- `Grammar.Core` không phụ thuộc native hay WPF, để `dotnet test` chạy được ở mọi nơi.
- `Grammar.Engine` tách khỏi Core, để test logic không phải kéo theo thư viện native.

### 3. Port logic thuần: giữ nguyên thuật toán, thêm test đối chiếu
- Port 1:1 `WordDiff` (Myers trên mảng token), `Tokenizer`, `EditGuard`, `CorrectionNormalizer`, `DiffHighlighter`, `OutputSanitizer`, `GrammarPrompt` (copy nguyên văn system prompt và ví dụ mẫu), `ResultCache` (LRU 200), `CaretContext`, `GoldenSet`.
- **Chuỗi:** `string` của C# là UTF-16, khớp với offset con trỏ của cả Accessibility lẫn UIA. Token giữ `(start, length)` theo UTF-16. `isLetter`/`isNumber` của Swift được thay bằng `Rune.IsLetter`/`Rune.IsDigit` trên từng `Rune`, để emoji và ký tự ngoài BMP không bị cắt đôi.
- **Đảo toạ độ:** `PanelLayout` viết lại theo hệ toạ độ gốc trên trái, nhưng giữ đúng quy tắc: cách mép 20, kẹp vào vùng hiển thị, giữ góc trên trái của vị trí đã kéo. Test được port bằng cách đảo trục y trong dữ liệu mong đợi.
- **CheckCoordinator:** `@MainActor` và `Task` được thay bằng `async`/`await` cùng `CancellationTokenSource`. Mọi thay đổi trạng thái chạy trên thread UI qua `SynchronizationContext`, nên test dùng một context giả. Debounce 700 ms dùng `Task.Delay` và đọc thời gian qua `TimeProvider`, để test giả lập thời gian mà không phải chờ thật. Trạng thái báo ra ngoài qua `INotifyPropertyChanged` để WPF binding.
- `PanelSettings` lưu vào `%APPDATA%\Grammar\settings.json` bằng `System.Text.Json`. Khi đọc thì kiểm tra từng trường, giá trị sai hoặc thiếu thì lấy mặc định, giống bản Mac.
- Lớp lưu trữ là một interface, để test không đụng tới đĩa.

### 4. Tách câu và nhận diện ngôn ngữ (thay NaturalLanguage)
- **`SentenceSegmenter`** (dùng chung cho `SentenceExtractor` và `EditGuard`):
  - Ranh giới câu: `.`, `!`, `?`, `…`, có thể kèm dấu đóng ngoặc hoặc ngoặc kép, theo sau là khoảng trắng hoặc hết chuỗi. Xuống dòng cũng là ranh giới.
  - Không tách tại từ viết tắt có trong danh sách (Mr., Mrs., Dr., e.g., i.e., etc., vs., U.S.), tại số thập phân (3.14), và tại dấu chấm giữa tên miền hoặc tên file (example.com, v1.2).
  - Test: các case đang có trong `PipelineTests` và `CaretContextTests`, cộng các case viết tắt kể trên.
- **`LanguageDetector`**: bộ phân loại EN/VI chạy trên máy, có tính điểm, không gọi mạng:
  1. Câu có ký tự đặc trưng tiếng Việt (đ, ă, â, ê, ô, ơ, ư hoặc dấu thanh) chiếm từ 15% số từ trở lên: không phải tiếng Anh.
  2. Câu không dấu: mỗi từ (viết thường) được so với hai danh sách nhúng sẵn. Một là khoảng 3.000 từ tiếng Anh thông dụng, có cả từ viết tắt kiểu chat (u, tmr, gonna, pls). Hai là các âm tiết tiếng Việt không dấu thông dụng (anh, em, giup, cai, nay, nhe, khong, duoc…).
  3. Từ có mặt ở cả hai danh sách, hoặc không có mặt ở danh sách nào, thì không tính điểm. Nhờ vậy tên riêng (Bao, Tuan) và thuật ngữ (PR, API) không làm lệch kết quả.
  4. Xác suất tiếng Anh = số từ tiếng Anh / (số từ tiếng Anh + số từ tiếng Việt). Không có từ nào được tính điểm thì coi là tiếng Anh, để không chặn câu toàn thuật ngữ. Ngưỡng ≥ 0.5, khớp `minimumConfidence` của bản Mac.
  - `LanguageGate` giữ nguyên interface (`Evaluate` trả về `English`/`NotEnglish`/`TooShort`, tối thiểu 3 từ).
  - Test bắt buộc: mọi scenario trong spec `grammar-correction`, toàn bộ câu trong `golden.json` (đều là tiếng Anh), và khoảng 30 câu tiếng Việt có dấu và không dấu kiểu chat công việc.
- **Đã cân nhắc:**
  - API ELS `MappingRecognizeText` của Windows: chỉ có trên Windows nên không test được trên Mac, và nhận diện câu ngắn kém.
  - NTextCat/Lingua .NET: thêm dependency nặng, nhận diện tiếng Việt không dấu kém, và vẫn phải tinh chỉnh cho tên riêng.
  - ICU BreakIterator (ICU4N): tách câu chuẩn hơn, nhưng thêm dependency lớn cho một việc mà vài quy tắc đã đủ.

### 5. Engine: LLamaSharp, ưu tiên Vulkan, dự phòng CPU
- Gói NuGet: `LLamaSharp`, `LLamaSharp.Backend.Cpu`, `LLamaSharp.Backend.Vulkan`. Trên Mac, test dùng backend Metal có sẵn trong gói Cpu (runtime osx-arm64). Ghim chính xác phiên bản trong `Directory.Packages.props`.
- `LlamaGrammarEngine` làm đúng các bước của bản Swift:
  - Sampler greedy, `ContextSize = 2048`, `BatchSize = 2048`.
  - Dựng prompt bằng chat template của model.
  - Giữ prefix cố định trong KV cache. Mỗi lần gọi chỉ xoá phần sau prefix khỏi sequence 0 rồi decode phần câu mới. Lỗi decode thì xoá toàn bộ KV cache và nạp lại từ đầu.
  - Dừng khi gặp EOG, hoặc gặp xuống dòng sau khi đã có nội dung, hoặc đạt `maxTokens = tokens(câu) × 2 + 16`.
  - Warm-up một câu sau khi nạp.
  - Dùng API mức thấp của LLamaSharp (`LLamaContext`, `LLamaBatch`, các hàm native), không dùng `InteractiveExecutor`/`StatelessExecutor`. Lý do: executor không cho điều khiển KV cache theo prefix.
- Mọi lời gọi native được xếp hàng qua một `SemaphoreSlim(1)`. Đây là bản tương đương `actor` của Swift: không bao giờ có hai lời gọi chạy song song.
- **`BackendSelector`:** khi nạp model, thử Vulkan với `GpuLayerCount = -1` (toàn bộ layer). Nếu không có thiết bị Vulkan, hoặc nạp model hay warm-up ném lỗi (ví dụ thiếu VRAM), giải phóng và nạp lại với `GpuLayerCount = 0` trên CPU. Kết quả (`Gpu`/`Cpu`) được báo lên Cài đặt.
- **Chọn model:** `ModelLocator` tìm theo thứ tự:
  1. `GRAMMAR_MODEL_PATH`.
  2. Model đã chọn trong settings, nếu file còn tồn tại.
  3. `Models\<defaultModelFileName>` cạnh `Grammar.exe`.
  Danh sách để chọn là các file `*.gguf` trong `Models\`. Đổi model thì huỷ engine cũ và nạp engine mới ở nền. Trong lúc nạp, panel ở trạng thái `loadingModel`.
- **Đã cân nhắc:**
  - Tự P/Invoke `llama.dll` từ release `b12376`: khớp hẳn phiên bản với bản Mac. Nhưng phải tự map các struct params (dễ sai âm thầm khi ABI đổi), và tự chọn biến thể DLL theo CPU (AVX2/AVX512).
  - ONNX Runtime GenAI + DirectML: phải chuyển model sang định dạng khác và không dùng chung được GGUF.
  - Ollama: phải cài thêm một service ngoài.

### 6. Đọc ô đang gõ bằng UI Automation
- Dùng COM `IUIAutomation` qua interop UIAutomationClient. Không dùng `System.Windows.Automation`, vì thư viện managed cũ này chậm và không có `TextPattern2`.
- **Threading:** một thread nền riêng, khởi tạo COM ở chế độ MTA, sở hữu toàn bộ object UIA và các event handler. Thread UI của WPF không bao giờ gọi UIA. Theo hướng dẫn của Microsoft, client UIA không được xử lý event trên thread có UI, nếu không sẽ dễ deadlock. Kết quả `(text, cursor)` được đẩy về thread UI qua `Dispatcher.BeginInvoke`.
- **Event:**
  - `AddFocusChangedEventHandler` để biết ô nào đang focus.
  - Trên ô đang focus: `UIA_Text_TextChangedEventId` và `UIA_Text_TextSelectionChangedEventId`.
  - Nếu hơn 1 giây không có event, hỏi lại mỗi 500 ms: ô focus còn là ô cũ không, rồi đọc lại. Giống `pollIfNeeded` của bản Mac.
  - Dùng `CacheRequest` để lấy một lần các thuộc tính `ProcessId`, `IsPassword`, `ControlType` và danh sách pattern được hỗ trợ.
- **Cách đọc** (tương đương nhánh text marker và nhánh `AXValue` của bản Mac):
  1. Có `TextPattern2`: dùng `GetCaretRange(out isActive)` làm vị trí con trỏ. Clone range đó rồi `ExpandToEnclosingUnit(Paragraph)` để được đoạn văn. Prefix là range từ đầu đoạn tới con trỏ (`MoveEndpointByRange`). Sau đó gọi `CaretContext.Normalize(paragraph, prefix)`.
  2. Chỉ có `TextPattern`: dùng `GetSelection()[0]` làm vị trí con trỏ, rồi làm giống bước 1.
  3. Chỉ có `ValuePattern`: lấy `CurrentValue`, con trỏ là `null`, nên lấy câu cuối.
  4. Không có pattern nào: bỏ qua ô đó.
  - Mọi lời gọi có timeout bằng `IUIAutomation.ConnectionTimeout` và `TransactionTimeout` (khoảng 250 ms, giống `AXUIElementSetMessagingTimeout`). App bị treo không làm treo Grammar.
- **Loại trừ:** `CurrentIsPassword` là true, hoặc `ProcessId` trùng process của app. Lỗi `E_ACCESSDENIED` hay `UIA_E_ELEMENTNOTAVAILABLE` (thường gặp khi app chạy quyền admin) thì bỏ qua ô đó một cách im lặng.
- **Chromium/Electron:** Chrome và Edge trên Windows đã hỗ trợ UIA, và tự bật cây accessibility khi có client UIA truy vấn. Electron (Slack, Discord) và WebView2 (Teams mới) chưa chắc làm vậy. Không tự bật cờ `SPI_SETSCREENREADER` toàn hệ thống. Kết quả từng app sẽ được ghi vào `docs/app-compatibility.md` sau khi test bằng `Grammar.Probe`.
- **Đã cân nhắc:**
  - Hook bàn phím (`WH_KEYBOARD_LL`) để ghép phím: sai khi dùng bộ gõ tiếng Việt (Unikey/EVKey), và bị phần mềm diệt virus coi là keylogger.
  - MSAA/IAccessible: cũ, không có thông tin con trỏ trong đoạn văn.

### 7. Panel WPF không lấy focus, click xuyên qua
- `PanelWindow` là một cửa sổ duy nhất:
  - `WindowStyle=None`, `AllowsTransparency=True`, `Background=Transparent`.
  - `Topmost=True`, `ShowInTaskbar=False`, `SizeToContent=Height`, `ShowActivated=False`.
- Trong `SourceInitialized`, thêm extended style `WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW`. Hook `WndProc` để trả `MA_NOACTIVATE` cho `WM_MOUSEACTIVATE`. Kết quả: click hay kéo không lấy focus của app đang gõ.
- **Click xuyên qua:**
  - Bật hoặc tắt `WS_EX_TRANSPARENT` (cùng `WS_EX_LAYERED`, mà WPF đã tự đặt khi trong suốt).
  - Một `DispatcherTimer` khoảng 30 ms đọc `GetCursorPos`. Chuột nằm trong dải header 24 DIP thì bỏ `WS_EX_TRANSPARENT`, ra ngoài thì đặt lại.
  - Timer chỉ chạy khi panel đang hiện và click xuyên qua đang bật.
  - Đây là cách tương đương `ignoresMouseEvents` cùng global mouse monitor của bản Mac.
  - **Đã cân nhắc:**
    - Tách header và nội dung thành hai cửa sổ: phải đồng bộ vị trí và thứ tự z, dễ bị lệch khi kéo.
    - Trả `HTTRANSPARENT` trong `WM_NCHITTEST`: chỉ chuyển click cho cửa sổ cùng thread, không chuyển được sang app khác.
    - Hook chuột `WH_MOUSE_LL`: nặng hơn và dễ bị phần mềm diệt virus nghi ngờ.
- **Kéo:** `MouseLeftButtonDown` trên header gọi `DragMove()`. Khi tắt click xuyên qua thì kéo được ở bất kỳ đâu trên panel. Khi `LocationChanged` xảy ra mà không phải do layout tự đặt, lưu vị trí đã kéo (DIP, góc trên trái).
- **Vị trí và DPI:**
  - Khai báo `PerMonitorV2` trong `app.manifest`.
  - Vùng làm việc lấy từ `MonitorFromRect` và `GetMonitorInfo().rcWork`, đổi sang DIP theo DPI của màn hình đó.
  - Gọi lại layout khi nội dung đổi chiều cao, khi `DpiChanged`, và khi `SystemEvents.DisplaySettingsChanged`.
- **Vẽ:** brush nền có alpha bằng độ mờ trong cài đặt. Header có alpha `max(độ mờ, 0.6)`. Chữ luôn đục.
- **TwoPaneView:** `TextBlock` với các `Run`:
  - Từ bị xoá hoặc thay: `TextDecoration` gạch dưới màu đỏ.
  - Chỗ thiếu từ: một `Run` khoảng trắng có nền đỏ nhạt và gạch dưới đỏ đậm.
  - Phần trên và phần dưới đều dựng từ kết quả của `DiffHighlighter` port.
  - Không cho chọn chữ, vì panel không nhận chuột.

### 8. Khay hệ thống, Cài đặt, vòng đời app
- `NotifyIcon` (WinForms) với `ContextMenuStrip` gồm: Ẩn/Hiện panel, Tạm dừng/Tiếp tục, Copy câu đã sửa, Cài đặt…, Thoát.
  - Trạng thái bật/tắt và vô hiệu của từng mục được cập nhật trong `Opening`.
  - Double-click icon thì hiện hoặc ẩn panel.
- Copy dùng `Clipboard.SetText` trên thread UI (STA), có thử lại vài lần nếu clipboard đang bị app khác giữ (`CLIPBRD_E_CANT_OPEN`).
- `SettingsWindow` là cửa sổ WPF thường, binding hai chiều vào `PanelSettings`, nên mọi thay đổi áp dụng ngay. Có thêm `ComboBox` chọn model và dòng "Đang chạy trên: GPU/CPU".
- **Một instance:**
  - Dùng `Mutex` có tên `Local\Grammar.SingleInstance`.
  - Bản chạy sau báo cho bản đang chạy hiện panel qua `EventWaitHandle` có tên, rồi thoát.
- App là WPF `Application` với `ShutdownMode=OnExplicitShutdown`, không có cửa sổ chính.
- Bỏ `PermissionView` và mọi code quyền. Không đăng ký hotkey nào.
- Icon `.ico` (16, 32, 48, 256 px) được sinh từ các PNG trong `AppIcon.appiconset` bằng một script và commit vào repo.

### 9. Đóng gói và build
- `scripts/publish.sh`:
  - Chạy `dotnet publish src/Grammar.App -c Release -r win-x64 --self-contained -p:PublishSingleFile=false`.
  - Publish `Grammar.Bench` và `Grammar.Probe` vào cùng thư mục với `Grammar.exe`. Cả ba dùng chung runtime .NET và thư viện llama.cpp; đặt trong thư mục con thì mỗi tool phải kèm thêm một bản runtime (~70 MB) và một bộ native (~70 MB).
  - Chỉ giữ `runtimes/win-x64` (LLamaSharp chép native của mọi nền tảng).
  - Nén thành `dist/Grammar-win-x64.zip`.
  - Không dùng single-file, vì thư viện native của LLamaSharp và Vulkan phải nằm cạnh exe.
- `scripts/download-model.ps1 <repo> <file>`: chạy trên Windows, tải từ Hugging Face vào `Models\`. Hoặc copy file `.gguf` có sẵn từ Mac sang.
- `windows/.gitignore` bỏ qua `bin/`, `obj/`, `dist/` và `Models/*.gguf`.
- (Tuỳ chọn) workflow GitHub Actions `windows-latest`: `dotnet build` cùng `dotnet test` cho Core. Đây là bằng chứng app build và test được trên Windows thật trước khi có máy.

## Risks / Trade-offs

- [Chrome, Slack, Teams không trả text qua UIA, và không có cách dự phòng] → Spike đầu tiên khi có máy, dùng `Grammar.Probe`. Ghi kết quả vào `docs/app-compatibility.md`. Nếu nhóm app quan trọng không đọc được, mở change riêng để bàn cách dự phòng không cần phím tắt.
- [7B chạy bằng CPU mất vài giây mỗi câu] → Debounce và cache giảm số lần gọi. Có thể chọn 3B trong Cài đặt. Đo bằng `Grammar.Bench` và ghi vào `docs/model-benchmark.md`.
- [Bản llama.cpp trong LLamaSharp khác `b12376` nên kết quả có thể lệch] → Golden set chạy với cả hai bản. Nếu không đạt ngưỡng thì chỉnh hoặc đổi phiên bản LLamaSharp trước khi làm UI.
- [Bộ nhận diện EN/VI tự viết sai ở câu sát ranh giới] → Test theo spec, golden set và các câu tiếng Việt thực tế. Ngưỡng và danh sách từ nằm trong resource, sửa được mà không đổi thuật toán.
- [WS_EX_NOACTIVATE cùng DragMove vẫn lấy focus trên một số bản Windows] → Có trong checklist test tay. Nếu xảy ra thì thay `DragMove` bằng kéo tự viết (`SetWindowPos` theo chuột) trong khi giữ `MA_NOACTIVATE`.
- [Timer 30 ms đọc vị trí chuột tốn CPU] → Chi phí rất nhỏ. Timer chỉ chạy khi panel hiện và click xuyên qua bật.
- [Hai bản logic lệch nhau theo thời gian] → Dùng chung golden.json. Thêm vào README quy tắc: sửa prompt, EditGuard, normalizer hay diff thì phải sửa cả hai bản và chạy cả hai bộ test.
- [SmartScreen cảnh báo exe chưa ký] → Chấp nhận với máy cá nhân. Ghi hướng dẫn "More info → Run anyway" trong README.
- [Gói Vulkan cần driver GPU hỗ trợ Vulkan] → Nếu không có driver thì tự chuyển sang CPU (quyết định 5).

## Migration Plan

Không có migration, đây là app mới trên nền tảng mới. Bản macOS và các spec hiện có vẫn đúng với macOS.

Lúc archive change này, cần sửa tay Purpose của spec `text-capture` (hiện ghi "trên macOS") thành ghi cả hai nền tảng.

## Open Questions

- Phiên bản LLamaSharp cụ thể: chọn bản mới nhất có backend Vulkan và Metal ổn định lúc bắt đầu làm. Không ảnh hưởng spec hay danh sách task.
- Ngưỡng 15% ký tự tiếng Việt, và độ dài danh sách từ, có thể chỉnh theo kết quả test.
