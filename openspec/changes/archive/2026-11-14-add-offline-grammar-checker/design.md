# Design

## Context

Dự án chưa có code. Phần lý do và phạm vi xem ở proposal.md, các yêu cầu hành vi xem ở `specs/` (text-capture, grammar-correction, checker-window).

Các ràng buộc ảnh hưởng tới cách làm:
- Môi trường phát triển: Apple Silicon (M4 Pro, 48 GB), macOS 26, Xcode 27, Swift 6 (strict concurrency).
- Đọc text của app khác bằng Accessibility API thì bắt buộc app không chạy trong sandbox, nên không phát hành qua App Store được. Với app dùng cá nhân thì chấp nhận được.
- Người dùng có dùng bộ gõ tiếng Việt, nên cách bắt từng phím rồi ghép lại thành text sẽ không đáng tin.

## Goals / Non-Goals

**Goals:**
- Tách rõ 4 tầng có thể test độc lập: lấy text, pipeline (lọc + debounce), engine (LLM), hiển thị (diff + UI).
- Engine nằm sau một protocol để đổi model hoặc runtime mà không đụng tới phần còn lại.
- Thêm một bộ đánh giá offline (golden set) để chọn model và chỉnh prompt dựa trên số liệu.

**Non-Goals:**
- Không vẽ gạch chân đè lên app khác như Grammarly. Không tự ghi câu sửa vào app khác.
- Không kiểm tra cả đoạn văn hay nhiều câu một lúc. Không giải thích lỗi theo luật ngữ pháp.
- Không làm màn hình Settings (blocklist app, đổi phím tắt) trong change này.
- Không ký số, notarize hay phân phối. Chỉ cần build chạy được trên máy.

## Decisions

### 1. Đọc text qua Accessibility observer, không bắt từng phím
- Dùng `NSWorkspace.didActivateApplicationNotification` để biết app nào đang ở phía trước. Với mỗi app đó tạo một `AXObserver` theo dõi `kAXFocusedUIElementChangedNotification` và `kAXValueChangedNotification`. Khi có thay đổi thì đọc `kAXValueAttribute` và `kAXSelectedTextRangeAttribute`.
- Với app nền Chromium (Chrome, Edge, Slack, Teams, app Electron), trước khi đọc thì set `AXManualAccessibility = true` (Electron) hoặc `AXEnhancedUserInterface = true` (Chrome) trên element của app để bật cây accessibility. Chỉ set cho đúng nhóm app này, vì `AXEnhancedUserInterface` có thể làm trình quản lý cửa sổ bị giật.
- Dự phòng: nếu sau khi focus mà không nhận được notification giá trị nào, chuyển sang hỏi lại ô đang focus mỗi 500 ms. Chỉ làm vậy khi app đang ở phía trước và không ở chế độ tạm dừng.
- Bỏ qua element có subrole `AXSecureTextField` và mọi element thuộc pid của chính app.
- **Phương án đã cân nhắc**: dùng `CGEventTap` bắt từng phím rồi ghép lại thành text. Bị loại vì ghép sai khi dùng bộ gõ tiếng Việt, khi paste hoặc di chuyển con trỏ, và còn cần thêm quyền Input Monitoring.

### 2. Phím tắt dự phòng cho đoạn bôi đen
- Đăng ký phím tắt toàn cục `⌃⌥G` qua Carbon `RegisterEventHotKey`, cách này không cần quyền Input Monitoring.
- Khi bấm phím tắt: lưu toàn bộ nội dung clipboard (mọi item và type), giả lập ⌘C bằng `CGEvent`, đợi `changeCount` của clipboard đổi (timeout khoảng 300 ms), đọc text, rồi khôi phục clipboard. Nếu `changeCount` không đổi thì coi như không có đoạn bôi đen.

### 3. Tách câu và nhận diện ngôn ngữ bằng NaturalLanguage
- `NLTokenizer(unit: .sentence)` trên toàn bộ text, chọn câu có range chứa vị trí con trỏ. Nếu không có vị trí con trỏ thì lấy câu cuối.
- `NLLanguageRecognizer`: ngôn ngữ chính là `.english`, xác suất ≥ 0.8, có ít nhất 3 từ.
- Cả hai có sẵn trong macOS, chạy offline và đủ nhanh để gọi mỗi lần text thay đổi.

### 4. Runtime LLM: llama.cpp (bản xcframework build sẵn)
- Dùng `llama.xcframework` từ release chính thức của ggml-org/llama.cpp (ghim một tag build cụ thể, ví dụ `b12376`). Metal shader đã được nhúng sẵn trong framework, nên lúc build **không cần Metal Toolchain**. Đây là lý do đổi từ MLX: máy dev được quản lý qua MDM và không tải được component Metal Toolchain (`xcodebuild -downloadComponent` bị lỗi khi lấy catalog).
- `scripts/fetch-llama.sh` tải và giải nén framework vào `Vendor/llama.xcframework` (git-ignored). Project link và nhúng framework này.
- Model ở định dạng GGUF, một file duy nhất, nạp bằng `llama_model_load_from_file` với toàn bộ layer chạy trên GPU (`n_gpu_layers = -1`).
- Prompt được dựng bằng `llama_chat_apply_template` với chat template lấy từ chính model (`llama_model_chat_template`). Qwen2.5 dùng ChatML, nằm trong danh sách template mà llama.cpp hỗ trợ sẵn.
- Vòng sinh: tokenize, rồi `llama_decode` cả prompt, rồi lặp lấy token bằng sampler greedy cho tới khi gặp token kết thúc (EOG) hoặc chạm `maxTokens`. Phần prompt cố định (system + ví dụ mẫu) được giữ lại trong KV cache giữa các lần gọi. Mỗi request chỉ xoá phần phía sau nó (`llama_memory_seq_rm`) rồi decode phần câu mới. Benchmark cho thấy cách này giảm p95 của 7B từ 1.66 giây xuống 0.45 giây mà kết quả sửa không đổi. Nếu có lỗi decode thì xoá toàn bộ KV cache rồi nạp lại từ đầu.
- **Phương án đã cân nhắc**:
  - MLX Swift (`mlx-swift-lm`): API mức cao và gọn hơn, nhưng phải biên dịch Metal shader lúc build. Máy này không cài được Metal Toolchain nên phải loại.
  - Apple Foundation Models: không cần tải model, nhưng phụ thuộc Apple Intelligence (có thể bị MDM tắt) và người dùng đã chọn dùng model tải kèm.
  - Ollama: phải cài thêm một tiến trình ngoài.
  - T5/CoEdIT: ít sửa quá tay, nhưng tích hợp vào Swift khó.
- `GrammarEngine` là protocol (`func correct(_ sentence: String) async throws -> String`), được implement bằng `actor LlamaGrammarEngine`. Mọi lời gọi C đều chạy trong actor này nên không bị gọi song song. Lúc khởi động nạp model và chạy một câu warm-up.

### 5. Chọn model bằng số liệu
- Ứng viên (GGUF Q4_K_M, một file): `Qwen2.5-7B-Instruct-Q4_K_M.gguf` (~4.7 GB) và `Qwen2.5-3B-Instruct-Q4_K_M.gguf` (~1.9 GB), lấy từ repo `bartowski/Qwen2.5-{3B,7B}-Instruct-GGUF`.
- Golden set khoảng 50 câu ở `GrammarAppTests/Fixtures/golden.json`, gồm câu sai có đáp án và câu đúng. Có thêm một benchmark target chạy engine thật, đo: tỉ lệ câu đúng được giữ nguyên, tỉ lệ khớp đáp án, tỉ lệ bị EditGuard loại, và độ trễ p50/p95.
- Mặc định chọn model nhỏ nhất đạt cả ba ngưỡng: giữ nguyên câu đúng ≥ 95%, khớp đáp án ≥ 80%, p95 ≤ 1.5 giây. Tên model là một hằng số trong config, đổi được.

### 6. Prompt và tham số sinh
- System prompt dặn: chỉ sửa ngữ pháp, chính tả, dấu câu; giữ nguyên từ ngữ, giọng văn, tên riêng; câu đúng thì trả nguyên văn; chỉ xuất ra câu, không giải thích, không đặt trong ngoặc kép. Kèm 3–4 ví dụ mẫu dạng cặp user/assistant, trong đó có một câu đúng trả nguyên văn và một câu thân mật chỉ sửa đúng lỗi ngữ pháp.
- `temperature = 0`, `maxTokens ≈ 2 × số token của câu + 16`.
- Hậu xử lý: cắt khoảng trắng, bỏ ngoặc kép bao ngoài, bỏ tiền tố kiểu "Corrected:", và chỉ lấy dòng đầu tiên.

### 7. Diff theo từng từ, dùng cho cả gạch chân và EditGuard
- Tách câu thành token gồm từ và dấu câu, mỗi token giữ `Range<String.Index>` trỏ về câu gốc. So sánh phân biệt hoa thường (để lỗi viết hoa như "i am" → "I am" cũng được đánh dấu) bằng `[String].difference(from:)` của Swift (thuật toán Myers).
- Từ diff suy ra:
  - removals → những từ trong câu gốc cần gạch chân đỏ.
  - insertions → những từ trong câu sửa cần làm nổi bật.
  - insertion không có removal tương ứng → tô đỏ (gạch chân đậm + nền đỏ nhạt) khoảng trống ở vị trí thiếu từ. Không chèn ký tự ‸ vì phần trên chỉnh sửa được, chèn ký tự sẽ làm thay đổi text của người dùng.
- Câu gốc và câu sửa giống hệt nhau (sau khi chuẩn hoá khoảng trắng) → trạng thái "không có lỗi".
- EditGuard: tỉ lệ thay đổi = số token gốc bị xoá / số token gốc. Nếu tỉ lệ > 0.4, hoặc câu sửa có nhiều câu hơn câu gốc (tức là hơn một câu khi câu gốc chỉ có một câu), thì trạng thái là "không chắc chắn".
- Lý do làm vậy: không bắt LLM tự trả về vị trí lỗi (model nhỏ thường làm sai), và chỉ cần một nguồn diff để vừa hiển thị vừa kiểm tra.

### 8. Pipeline và concurrency
- `CheckCoordinator` (`@MainActor`, `ObservableObject`/`@Observable`) nhận text từ capture, chờ 700 ms sau lần thay đổi cuối, rồi chạy một `Task` mới và huỷ Task cũ. Kết quả chỉ được áp dụng nếu câu hiện tại vẫn trùng với câu đã gửi đi kiểm tra.
- Cache LRU khoảng 200 mục, key là câu đã chuẩn hoá, chỉ giữ trong bộ nhớ.
- Trạng thái hiển thị là một enum: `idle`, `checking`, `ok`, `corrected(diff)`, `notEnglish`, `uncertain`, `modelError(message)`.

### 9. UI
- `NSPanel` với style `.nonactivatingPanel` + `.utilityWindow`, `level = .floating`, `hidesOnDeactivate = false`, nội dung là `NSHostingView` chứa SwiftUI. Nhờ vậy panel cập nhật mà không lấy focus.
- Phần trên là ô text chỉnh sửa được (để nhập tay), hiển thị `AttributedString` với `underlineStyle = .single` và `underlineColor = .systemRed`. Khi người dùng gõ vào đây thì chuyển nguồn text sang nhập tay.
- Phần dưới là text chọn được để copy, từ được thêm hoặc thay đổi tô `.systemGreen` và in đậm.
- `MenuBarExtra` có các mục Hiện/Ẩn, Tạm dừng/Tiếp tục, Thoát. Đặt `LSUIElement = YES` để app không có icon trên Dock.
- Màn hình hướng dẫn cấp quyền: gọi `AXIsProcessTrustedWithOptions`, có nút mở `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, và kiểm tra lại quyền mỗi giây cho tới khi được cấp.

### 10. Cấu trúc project và build
- Dùng XcodeGen (`project.yml`) để sinh `GrammarApp.xcodeproj`, build bằng `xcodebuild`. Có `project.yml` thì cấu hình project đọc và review được, không phải sửa file `pbxproj`.
- Các target:
  - `GrammarKit`: framework chứa logic thuần (Diff, Pipeline, Engine), không phụ thuộc Accessibility. Unit test và benchmark dùng được mà không phải khởi động app.
  - `GrammarApp`: app, không sandbox, Hardened Runtime tắt khi dev. Gồm App, Capture, UI.
  - `GrammarAppTests`: unit test cho GrammarKit, không cần model.
  - `GrammarBench`: command-line tool chạy golden set với model thật.
- `scripts/download-model.sh <repo-id> <file.gguf>` tải bằng `curl` từ Hugging Face về `GrammarApp/Resources/Models/`. Thư mục này nằm trong `.gitignore` và được copy vào bundle bằng một build phase "folder reference".

```
GrammarKit/
  Diff/       Tokenizer, WordDiff, EditGuard
  Pipeline/   SentenceExtractor, LanguageGate, CheckCoordinator, ResultCache
  Engine/     GrammarEngine, LlamaGrammarEngine, GrammarPrompt, OutputSanitizer
GrammarApp/
  App/        GrammarApp.swift, AppDelegate, MenuBarContent, PermissionView
  Capture/    AXTextCapture, ChromiumAccessibility, SelectionHotkey
  UI/         CheckerPanel, TwoPaneView
  Resources/Models/   (git-ignored)
Vendor/llama.xcframework  (git-ignored, tải bằng scripts/fetch-llama.sh)
GrammarAppTests/  GrammarBench/  scripts/  project.yml
```

## Risks / Trade-offs

- [Teams hoặc Slack không trả về giá trị ô nhập dù đã bật cờ accessibility] → Dùng phím tắt `⌃⌥G` và nhập tay. Ghi kết quả test tay từng app vào README.
- [Model vẫn sửa quá tay hoặc bỏ sót lỗi] → Dùng golden set, EditGuard, temperature 0 và ví dụ mẫu. Có thể chuyển sang model 7B mà không đổi code.
- [Máy công ty chặn quyền Accessibility qua MDM] → Phát hiện sớm ở màn hình hướng dẫn cấp quyền. Nếu bị chặn thì vẫn dùng được nhập tay trong panel (không cần quyền), riêng `⌃⌥G` cần quyền để giả lập ⌘C.
- [App nặng vài GB và RAM tăng khoảng 2–5 GB khi đã nạp model] → Chấp nhận được với máy 48 GB. Model nạp một lần lúc khởi động.
- [Clipboard bị ghi đè trong lúc dùng ⌃⌥G] → Lưu và khôi phục toàn bộ item. Thời gian bị đổi rất ngắn, dưới 300 ms.
- [`AXEnhancedUserInterface` gây giật animation cửa sổ của Chrome] → Chỉ set cho app Chromium và chỉ một lần mỗi lần app được kích hoạt.
- [Tự viết vòng sinh qua C API của llama.cpp dễ rò rỉ bộ nhớ hoặc sai khi tokenize] → Gói gọn trong một actor. Giải phóng model, context và sampler trong `deinit`. Kiểm tra bằng test tích hợp với model thật và bằng `GrammarBench`.
- [C API của llama.cpp thay đổi giữa các bản build] → Ghim tag release trong `scripts/fetch-llama.sh`.
- [Chạy LLM liên tục gây nóng máy và tốn pin] → Debounce, cache, chỉ kiểm tra câu tiếng Anh từ 3 từ trở lên, và có chế độ tạm dừng.

## Migration Plan

Không có, đây là app mới. Muốn rollback chỉ cần xoá app và gỡ quyền Accessibility.

## Open Questions

- Model mặc định là 3B hay 7B: quyết định sau khi chạy `GrammarBench`. Không ảnh hưởng spec hay danh sách task.
- Ngưỡng EditGuard 0.4 và thời gian debounce 700 ms có thể chỉnh sau khi dùng thử.
