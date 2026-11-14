# Tasks

## 1. Khung project và dependency

- [x] 1.1 Cài XcodeGen (`brew install xcodegen`). Kiểm tra: `xcodegen --version` chạy được.
- [x] 1.2 Tạo `project.yml` với 3 target `GrammarApp` (macOS 26, Swift 6, không sandbox, `LSUIElement = YES`), `GrammarAppTests`, `GrammarBench`, cùng thư mục nguồn theo design (App, Capture, Pipeline, Engine, Diff, UI). Kiểm tra: `xcodegen generate` sinh ra `GrammarApp.xcodeproj`.
- [x] 1.3 Viết `scripts/fetch-llama.sh` (ghim tag llama.cpp, tải `llama.xcframework` vào `Vendor/`) và link + nhúng framework vào `GrammarKit`/`GrammarApp`. Kiểm tra: `xcodebuild -scheme GrammarApp build` thành công mà không cần Metal Toolchain.
- [x] 1.4 Thêm `.gitignore` (bỏ qua `GrammarApp/Resources/Models/`, `Vendor/`, `*.xcodeproj/xcuserdata`, `build/`). Kiểm tra: `git check-ignore GrammarApp/Resources/Models/x` trả về đường dẫn.

## 2. Diff và EditGuard

- [x] 2.1 Viết `Tokenizer`: tách câu thành token (từ và dấu câu), mỗi token giữ range trỏ về câu gốc. Kiểm tra: unit test có dấu nháy (don't), dấu câu dính liền từ, nhiều khoảng trắng.
- [x] 2.2 Viết `WordDiff` dùng `[String].difference(from:)`, trả về danh sách range bị xoá hoặc thay trong câu gốc, range được thêm trong câu sửa, và các vị trí thiếu từ. Kiểm tra: unit test cho các ví dụ trong spec checker-window ("He have" → "He has", "I going" → "I am going") và trường hợp hai câu giống hệt nhau.
- [x] 2.3 Viết `EditGuard`: tỉ lệ thay đổi > 0.4 hoặc câu sửa có nhiều hơn một câu thì trả về "không chắc chắn". Kiểm tra: unit test với câu bị viết lại hoàn toàn, câu sửa 1 từ, và câu sửa ra 2 câu.

## 3. Engine LLM offline

- [x] 3.1 Viết `scripts/download-model.sh <hf-repo-id> <file.gguf>`: tải bằng `curl` (tiếp tục được khi bị ngắt) vào `GrammarApp/Resources/Models/`. Tải `bartowski/Qwen2.5-3B-Instruct-GGUF` và `bartowski/Qwen2.5-7B-Instruct-GGUF` bản `Q4_K_M`. Kiểm tra: file `.gguf` tồn tại, 4 byte đầu là `GGUF`.
- [x] 3.2 Cấu hình build phase copy thư mục `Resources/Models` vào app bundle, tên model mặc định lấy từ một hằng số. Kiểm tra: sau khi build, `Grammar.app/Contents/Resources/Models/<file>.gguf` tồn tại.
- [x] 3.3 Viết protocol `GrammarEngine`, `GrammarPrompt` (system prompt + 3–4 ví dụ mẫu theo design §6) và `OutputSanitizer` (bỏ ngoặc kép, bỏ tiền tố "Corrected:", chỉ lấy dòng đầu). Kiểm tra: unit test cho `OutputSanitizer`.
- [x] 3.4 Viết `actor LlamaGrammarEngine`: nạp GGUF từ bundle (GPU toàn bộ layer), dựng prompt bằng chat template của model, vòng decode greedy tới token EOG hoặc `maxTokens`, xoá KV cache mỗi request, warm-up. Lỗi nạp model ném ra lỗi có thông báo rõ ràng. Kiểm tra: một test (bỏ qua khi không có model) sửa "They was happy." thành "They were happy." khi đã tắt mạng.
- [x] 3.5 Tạo `GrammarAppTests/Fixtures/golden.json` khoảng 50 câu: khoảng 30 câu sai có đáp án (chia động từ, mạo từ, số ít/nhiều, thì, giới từ, chính tả, câu thân mật) và khoảng 20 câu đúng. Kiểm tra: file parse được và có cả hai loại câu.
- [x] 3.6 Viết target `GrammarBench`: chạy golden set qua engine và EditGuard, in ra tỉ lệ giữ nguyên câu đúng, tỉ lệ khớp đáp án, tỉ lệ bị EditGuard loại, độ trễ p50/p95. Kiểm tra: chạy được với cả hai model.
- [x] 3.7 Chạy benchmark cho cả hai model, chọn mặc định theo ngưỡng ở design §5 (giữ nguyên ≥ 95%, khớp ≥ 80%, p95 ≤ 1.5 giây), chỉnh prompt nếu cần. Ghi kết quả vào `docs/model-benchmark.md`. Kiểm tra: model được chọn đạt cả ba ngưỡng, hoặc ghi rõ ngưỡng nào chưa đạt.

## 4. Pipeline kiểm tra

- [x] 4.1 Viết `SentenceExtractor` (NLTokenizer, chọn câu chứa vị trí con trỏ, không có con trỏ thì lấy câu cuối). Kiểm tra: unit test với "I like tea. He have two cats. We are fine." ở các vị trí con trỏ khác nhau.
- [x] 4.2 Viết `LanguageGate` (tiếng Anh, xác suất ≥ 0.8, ít nhất 3 từ). Kiểm tra: unit test câu tiếng Anh, câu tiếng Việt, "ok thanks", câu trộn hai thứ tiếng.
- [x] 4.3 Viết `ResultCache` (LRU 200 mục, chỉ trong bộ nhớ). Kiểm tra: unit test việc loại mục cũ và trúng cache.
- [x] 4.4 Viết `CheckCoordinator` (`@MainActor`): debounce 700 ms, huỷ Task cũ, bỏ kết quả của câu đã cũ, quản lý enum trạng thái (`idle`, `checking`, `ok`, `corrected`, `notEnglish`, `uncertain`, `modelError`). Kiểm tra: unit test với engine giả lập độ trễ (gõ liên tục thì không gọi engine, câu cũ không ghi đè câu mới, trúng cache thì không gọi engine).

## 5. Lấy text từ app khác

- [x] 5.1 Viết màn hình hướng dẫn cấp quyền (`AXIsProcessTrustedWithOptions`, nút mở System Settings, kiểm tra lại mỗi giây và tự bắt đầu theo dõi khi có quyền). Kiểm tra bằng tay: gỡ quyền, chạy app thấy hướng dẫn, cấp quyền thì app tự bắt đầu theo dõi mà không cần khởi động lại.
- [x] 5.2 Viết `AXTextCapture`: theo dõi app đang ở phía trước, `AXObserver` theo dõi focus và giá trị, đọc value và vị trí con trỏ, bỏ qua `AXSecureTextField` và pid của chính app, chuyển sang hỏi lại mỗi 500 ms khi không nhận được notification. Kiểm tra bằng tay: TextEdit và Notes cập nhật panel; ô mật khẩu trong Safari không hiển thị gì.
- [x] 5.3 Viết `ChromiumAccessibility`: nhận diện app Chromium/Electron theo bundle id và set `AXManualAccessibility` hoặc `AXEnhancedUserInterface`. Kiểm tra bằng tay: đọc được ô soạn thư Gmail trong Chrome và ô nhắn tin Slack; ghi kết quả Teams vào `docs/app-compatibility.md`.
- [x] 5.4 Viết `SelectionHotkey`: phím tắt `⌃⌥G` qua Carbon, lưu và khôi phục toàn bộ clipboard, giả lập ⌘C, đợi `changeCount` tối đa 300 ms. Kiểm tra bằng tay: bôi đen trong Teams rồi bấm phím tắt thì panel hiển thị đúng đoạn đó và clipboard vẫn như cũ; không bôi đen gì thì panel giữ nguyên.

## 6. Panel và menu bar

- [x] 6.1 Viết `CheckerPanel` (`NSPanel` không lấy focus, luôn nổi trên cùng, không ẩn khi app mất focus) chứa `TwoPaneView`. Kiểm tra bằng tay: gõ trong Slack trong lúc panel cập nhật thì con trỏ vẫn ở Slack.
- [x] 6.2 Viết `TwoPaneView`: phần trên chỉnh sửa được, gạch chân đỏ và tô đỏ khoảng trống ở chỗ thiếu từ theo `WordDiff`; phần dưới chọn được để copy, từ thay đổi tô xanh và đậm; có dòng trạng thái. Kiểm tra: test snapshot hoặc test cho hàm dựng `AttributedString` với ví dụ trong spec, và kiểm tra bằng tay việc copy câu sửa.
- [x] 6.3 Khi người dùng gõ hoặc dán vào phần trên thì chuyển nguồn text sang nhập tay. Kiểm tra bằng tay: dán "He don't know nothing." thì có kết quả kiểm tra.
- [x] 6.4 Viết `MenuBarExtra` (Hiện/Ẩn panel, Tạm dừng/Tiếp tục, Thoát), không có icon trên Dock. Kiểm tra bằng tay: Tạm dừng thì panel ngừng cập nhật, Tiếp tục thì chạy lại.
- [x] 6.5 Viết `README.md` gồm cách tải model, build (`xcodegen generate` + `xcodebuild`), cấp quyền, phím tắt và các giới hạn đã biết. Kiểm tra: làm theo README từ một bản clone sạch thì build và chạy được.

## 7. Kiểm tra tích hợp

- [x] 7.1 Chạy toàn bộ unit test (`xcodebuild test -scheme GrammarApp`). Kiểm tra: tất cả pass.
- [x] 7.2 Test end-to-end khi tắt Wi-Fi: gõ câu sai trong TextEdit, Notes, Mail, Safari, Chrome (Gmail), Slack, Teams. Kiểm tra: panel gạch chân đúng cụm sai, câu sửa đúng, độ trễ dưới 1.5 giây. Ghi kết quả từng app vào `docs/app-compatibility.md`.
- [x] 7.3 Kiểm tra quyền riêng tư và các trường hợp lọc: ô mật khẩu không bị đọc, câu tiếng Việt báo "không phải tiếng Anh", câu đúng báo "Không có lỗi ngữ pháp", không có kết nối mạng ra ngoài (dùng Little Snitch hoặc `nettop`). Kiểm tra: tất cả đúng như spec.

## Workflow follow-up

- Archive change bằng `/opsx:archive` sau khi đã dùng thử và hài lòng.
