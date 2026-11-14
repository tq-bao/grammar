# Grammar cho Windows

Bản Windows của Grammar: kiểm tra ngữ pháp tiếng Anh **offline** cho câu bạn đang gõ ở bất kỳ app nào (Notepad, Word, Outlook, trình duyệt…). Panel nổi, trong suốt, click xuyên qua:

- **Phần trên:** câu bạn đang gõ, gạch chân đỏ dưới cụm sai. Chỗ thiếu từ được tô đỏ.
- **Phần dưới:** câu đã sửa, phần sửa được tô xanh. Muốn copy câu sửa thì chuột phải icon Grammar ở khay hệ thống, chọn **Copy câu đã sửa**.

App chỉ sửa ngữ pháp, chính tả và dấu câu, giữ nguyên ý và giọng văn, và **không bao giờ ghi vào app bạn đang gõ**. Model (Qwen2.5-7B-Instruct, GGUF 4-bit) chạy trên máy qua llama.cpp. Nội dung bạn gõ không bị gửi ra ngoài và không bị lưu xuống đĩa.

Chức năng giống bản macOS, với vài khác biệt:

| | macOS | Windows |
|---|---|---|
| Điều khiển | Menu bar | Icon ở khay hệ thống (góc phải taskbar) |
| Phím tắt `⌃⌥C` (copy câu sửa), `⌃⌥G` (kiểm tra đoạn bôi đen) | Có | **Không có.** Copy qua menu khay. Không có cách kiểm tra đoạn bôi đen |
| Quyền | Cần cấp quyền Accessibility | Không cần cấp quyền gì |
| Chọn model | Không | Có, trong Cài đặt (nếu thư mục `Models` có nhiều model) |

## Yêu cầu máy

- Windows 10 hoặc 11, 64-bit (x64). Máy Windows ARM chạy qua giả lập, sẽ chậm.
- RAM: nên có từ 16 GB. Model 7B chiếm khoảng 5–6 GB khi chạy.
- GPU (không bắt buộc): card có driver hỗ trợ Vulkan (NVIDIA, AMD, Intel). App tự dùng GPU nếu được, không được thì tự chạy bằng CPU. Xem dòng "Đang chạy trên" trong Cài đặt.
- Khoảng 5 GB ổ đĩa cho model và 250 MB cho app.

## Cài đặt

1. Giải nén `Grammar-win-x64.zip` vào một thư mục, ví dụ `C:\Users\<bạn>\Apps\Grammar`. Không cần cài .NET, không cần quyền admin.
2. Đặt file model vào thư mục `Models\` bên trong. Có hai cách:
   - Tải bằng script (khoảng 4.7 GB, tải tiếp được nếu bị ngắt):
     ```powershell
     powershell -ExecutionPolicy Bypass -File download-model.ps1
     ```
   - Hoặc copy file `Qwen2.5-7B-Instruct-Q4_K_M.gguf` có sẵn từ máy khác, ví dụ từ `GrammarApp/Resources/Models/` của bản macOS.
3. Chạy `Grammar.exe`. Lần đầu, Windows SmartScreen có thể báo "Windows protected your PC" vì app chưa được ký số. Chọn **More info**, rồi **Run anyway**.

Muốn app tự chạy khi đăng nhập: nhấn `Win+R`, gõ `shell:startup`, rồi tạo shortcut tới `Grammar.exe` trong thư mục vừa mở.

Máy yếu (không có GPU, hoặc ít RAM) có thể dùng model 3B, nhanh hơn nhưng bỏ sót nhiều lỗi hơn:

```powershell
powershell -ExecutionPolicy Bypass -File download-model.ps1 -Repo bartowski/Qwen2.5-3B-Instruct-GGUF -File Qwen2.5-3B-Instruct-Q4_K_M.gguf
```

Sau đó chọn model 3B trong **Cài đặt**.

## Cách dùng

| Thao tác | Kết quả |
|---|---|
| Gõ tiếng Anh ở app bất kỳ rồi dừng khoảng 0.7 giây | Panel kiểm tra câu đang chứa con trỏ |
| Chuột phải icon khay › **Copy câu đã sửa** | Copy câu đã sửa vào clipboard (chỉ khi panel đang báo có lỗi) |
| Chuột phải icon khay › Ẩn/Hiện panel, Tạm dừng/Tiếp tục, Thoát | |
| Double-click icon khay | Ẩn/hiện panel |
| Chuột phải icon khay › **Cài đặt…** | Độ mờ nền (0–100%), click xuyên qua (tắt để kéo panel), góc màn hình, độ rộng panel, model. Thay đổi áp dụng ngay và được lưu lại |

**Di chuyển panel:** nhấn giữ dải **header** ở trên cùng panel (biểu tượng ≡ và chữ "Grammar") rồi kéo. Header luôn nhận chuột, phần còn lại của panel cho click xuyên qua. Vị trí đã kéo được lưu lại. Bấm **Về góc đã chọn** trong Cài đặt để đưa panel về góc.

Cài đặt được lưu ở `%APPDATA%\Grammar\settings.json`.

## Giới hạn đã biết

- Chỉ kiểm tra **một câu** (câu chứa con trỏ). Câu dưới 3 từ và câu không phải tiếng Anh bị bỏ qua.
- Ô mật khẩu không bao giờ được đọc.
- App đọc ô đang gõ qua UI Automation của Windows. App nào không hỗ trợ thì **không kiểm tra được**, vì bản Windows không có phím tắt dự phòng. Xem `docs/app-compatibility.md` ở thư mục gốc repo.
- **App chạy bằng quyền admin** ("Run as administrator") không đọc được: Windows chặn app thường đọc app quyền cao hơn.
- Chạy bằng CPU thì mỗi câu có thể mất vài giây. Panel báo "Đang kiểm tra" trong lúc chờ.

## Chẩn đoán

### App không đọc đúng câu đang gõ

Dùng `Grammar.Probe.exe` (nằm cạnh `Grammar.exe`), bản Windows của `scripts/ax-probe.swift`.

```powershell
.\Grammar.Probe.exe            # chờ 5 giây rồi đọc ô đang focus
.\Grammar.Probe.exe 10         # chờ 10 giây
.\Grammar.Probe.exe slack      # chờ tới khi cửa sổ của process "slack" ở phía trước, đợi thêm 3 giây
```

Chạy lệnh, chuyển sang app cần kiểm tra, rồi đặt con trỏ vào ô đang gõ. Probe in ra:

- process, loại ô và các pattern UI Automation mà ô hỗ trợ (TextPattern2, TextPattern, ValuePattern);
- đoạn văn và vị trí con trỏ theo từng cách đọc mà Grammar dùng;
- câu mà Grammar sẽ kiểm tra.

Probe chỉ đọc, không lưu nội dung, và không in nội dung ô mật khẩu.

### Đo tốc độ và độ chính xác trên máy này

```powershell
.\Grammar.Bench.exe --model Models\Qwen2.5-7B-Instruct-Q4_K_M.gguf
.\Grammar.Bench.exe --model Models\Qwen2.5-7B-Instruct-Q4_K_M.gguf --cpu    # ép chạy bằng CPU
```

Bench chạy golden set (`golden.json`, dùng chung với bản macOS), rồi in tỷ lệ giữ nguyên câu đúng, tỷ lệ khớp đáp án, độ trễ p50/p95 và phần cứng đang dùng. Ghi kết quả vào `docs/model-benchmark.md`, mục "Máy Windows thật".

### App gặp lỗi

Lỗi không lường trước được ghi vào `%LOCALAPPDATA%\Grammar\error.log`. File chỉ chứa loại lỗi và stack trace, không chứa nội dung bạn gõ.

## Phát triển

Code nằm trong `windows/`, viết bằng C# trên .NET 10 và WPF. Build, chạy test và đóng gói được trên macOS. Chạy app thì cần Windows.

```bash
# .NET 10 SDK (trên Mac, không cần quyền admin):
#   curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0
#   export PATH="$HOME/.dotnet:$PATH"

cd windows
dotnet build Grammar.sln                    # build tất cả, kể cả app WPF (EnableWindowsTargeting)
dotnet test Grammar.sln                     # unit test; test có model thật tự bỏ qua nếu chưa có model
./scripts/publish.sh                        # tạo dist/Grammar-win-x64.zip
```

Test engine dùng model ở `GrammarApp/Resources/Models/` của bản macOS, hoặc file chỉ định bằng biến môi trường `GRAMMAR_MODEL_PATH`.

Cấu trúc:

```
windows/
  src/Grammar.Core/      logic thuần, đa nền tảng: Diff, Text (tách câu, nhận diện ngôn ngữ), Pipeline,
                         Panel (bố cục, cài đặt, nội dung panel), Engine (prompt, sanitizer, tìm model), Capture (chọn cách đọc ô)
  src/Grammar.Engine/    llama.cpp qua LLamaSharp: LlamaGrammarEngine, BackendSelector (GPU -> CPU)
  src/Grammar.App/       app WPF: Capture (UI Automation), UI (panel, cài đặt), Tray, AppController
  src/Grammar.Bench/     benchmark golden set
  src/Grammar.Probe/     chẩn đoán UI Automation
  tests/                 xUnit: Grammar.Core.Tests (chạy mọi nơi), Grammar.Engine.Tests (cần model)
  scripts/               publish.sh, download-model.ps1, make-icon.sh, gen-*.swift (sinh fixture đối chiếu với macOS)
  docs/manual-test.md    checklist test tay trên Windows
```

### Giữ hai bản khớp nhau

Logic có hai bản: Swift (`GrammarKit/`) và C# (`windows/src/Grammar.Core/`). **Sửa prompt, EditGuard, normalizer, diff hay bộ lọc ngôn ngữ thì phải sửa cả hai bản và chạy cả hai bộ test.** Các test sau giúp phát hiện lệch:

- `GrammarPromptParityTests` đọc `GrammarKit/Engine/GrammarPrompt.swift` và so từng chuỗi prompt với bản C#.
- `MyersParityTests` so thuật toán diff với `difference(from:)` thật của Swift (`Fixtures/myers-swift.json`, sinh bằng `scripts/gen-myers-fixture.swift`).
- `SentenceSegmenterParityTests` so cách tách câu với `NLTokenizer` của macOS (`Fixtures/sentences-nltokenizer.json`, sinh bằng `scripts/gen-sentence-fixture.swift`).
- `LanguageGateParityTests` so quyết định lọc ngôn ngữ với `LanguageGate.swift` thật (`Fixtures/language-oracle.json`, sinh bằng `scripts/gen-language-oracle.swift`).
- Golden set `GrammarAppTests/Fixtures/golden.json` dùng chung cho `GrammarBench` (macOS) và `Grammar.Bench` (Windows).

Sửa logic bên Swift thì chạy lại các script `gen-*.swift` trên Mac để cập nhật fixture, rồi chạy `dotnet test`.
