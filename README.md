# Grammar

App menu bar cho macOS, kiểm tra ngữ pháp tiếng Anh **offline**. App đọc câu bạn đang gõ ở bất kỳ app nào (Slack, Teams, Chrome, Notes…). Nếu câu là tiếng Anh, app hiển thị trong một panel nổi:

- **Phần trên:** câu bạn đang gõ, gạch chân đỏ dưới cụm sai (khoảng trống được tô đỏ ở chỗ thiếu từ).
- **Phần dưới:** câu đã sửa, phần sửa được tô xanh. Bấm **⌃⌥C** (hoặc menu bar › Copy câu đã sửa) để copy.

Panel **chỉ để xem**. Nền trong suốt theo cài đặt, và mặc định mọi click hay cuộn chuột trên panel đều đi xuyên xuống app phía sau. Độ mờ nền, góc màn hình và độ rộng chỉnh trong **Cài đặt**.

**Di chuyển panel:** nhấn giữ dải **header** ở trên cùng panel (có biểu tượng ≡ và chữ "Grammar") rồi kéo. Header luôn nhận chuột và luôn có nền mờ tối thiểu 60%, kể cả khi bạn đặt độ mờ nền 0%. Phần còn lại của panel vẫn cho click xuyên qua.

Muốn kéo được ở bất kỳ đâu trên panel thì vào Cài đặt và tắt **Click xuyên qua panel** (panel hiện viền nét đứt). Kéo xong thì bật lại.

Vị trí đã kéo được lưu lại, kể cả sau khi khởi động lại app. Bấm **Về góc đã chọn**, hoặc chọn một góc khác, để đưa panel về góc.

App chỉ sửa ngữ pháp, chính tả và dấu câu, giữ nguyên ý và giọng văn, và **không bao giờ ghi vào app bạn đang gõ**. Model ngôn ngữ (Qwen2.5-7B-Instruct, GGUF 4-bit) chạy trên máy qua llama.cpp. Nội dung bạn gõ không bị gửi ra ngoài và không bị lưu xuống đĩa.

## Yêu cầu

- Mac Apple Silicon, macOS 26 trở lên, nên có từ 16 GB RAM (model 7B chiếm khoảng 5 GB khi chạy).
- Xcode 27 và [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- **Không** cần Metal Toolchain: llama.cpp được dùng ở dạng xcframework build sẵn, Metal shader đã nhúng bên trong.

## Build

```bash
# 1. Tải llama.xcframework (ghim tag b12376) vào Vendor/
./scripts/fetch-llama.sh

# 2. Tải model mặc định (~4.7 GB) vào GrammarApp/Resources/Models/
./scripts/download-model.sh bartowski/Qwen2.5-7B-Instruct-GGUF Qwen2.5-7B-Instruct-Q4_K_M.gguf

# 3. Sinh Xcode project và build
xcodegen generate
xcodebuild -project GrammarApp.xcodeproj -scheme GrammarApp -configuration Release -derivedDataPath build build

# 4. Chạy
open build/Build/Products/Release/Grammar.app
```

### Cài vào /Applications (khuyên dùng)

```bash
./scripts/create-signing-cert.sh   # chỉ cần chạy một lần
./scripts/install.sh               # build Release, cài vào /Applications, ký, rồi mở app
```

- `create-signing-cert.sh` tạo chứng chỉ ký code tự ký **Grammar Local Signing** trong login keychain.
- `install.sh` ký app bằng chứng chỉ này, nên macOS nhận diện app theo bundle id và chứng chỉ thay vì theo mã băm của từng bản build. Nhờ vậy **quyền Accessibility còn nguyên sau mỗi lần cài lại**.
- Nếu không có chứng chỉ thì `install.sh` ký ad-hoc, và bạn phải cấp lại quyền sau mỗi lần cài.
- Bản cài chỉ giữ model mặc định.

Icon của app được vẽ bằng `swift scripts/make-icon.swift`. Script này sinh `GrammarApp/Resources/Assets.xcassets/AppIcon.appiconset`.

Khi build thủ công như ở bước 3, mọi file `.gguf` trong `GrammarApp/Resources/Models/` đều được copy vào app bundle. Muốn app nhẹ hơn thì chỉ để lại model mặc định.

## Lần chạy đầu: cấp quyền Accessibility

App cần quyền **Accessibility** để đọc ô nhập liệu ở app khác và để giả lập ⌘C cho phím tắt.

1. Khi app hỏi, chọn **Open System Settings**, hoặc chọn menu bar › **Cấp quyền Accessibility…**.
2. Bật **Grammar** trong System Settings › Privacy & Security › Accessibility.
3. App tự bắt đầu theo dõi trong vòng 1 giây, không cần khởi động lại.

> Nếu bật quyền rồi mà panel vẫn báo thiếu quyền, nghĩa là mục Grammar trong danh sách thuộc về một bản build cũ (ký ad-hoc). Chọn mục đó, bấm **−** để xoá, rồi bấm **+** để thêm lại `/Applications/Grammar.app`. Khi đã cài bằng `scripts/install.sh` và có chứng chỉ, bạn chỉ cần làm việc này một lần.
>
> Trên máy công ty quản lý bằng MDM, IT có thể chặn quyền này. **Khi đó app không nhận được câu nào**, vì panel chỉ để xem và phím tắt ⌃⌥G cũng cần quyền này để lấy đoạn bôi đen.

## Cách dùng

| Thao tác | Kết quả |
|---|---|
| Gõ tiếng Anh ở app bất kỳ rồi dừng khoảng 0.7 giây | Panel kiểm tra câu đang chứa con trỏ |
| Bôi đen một đoạn rồi bấm **⌃⌥G** | Kiểm tra đoạn đó. Dùng cho app không đọc được ô nhập. Clipboard được khôi phục như cũ |
| **⌃⌥C** hoặc menu bar › Copy câu đã sửa | Copy câu đã sửa vào clipboard (chỉ khi panel đang báo có lỗi) |
| Menu bar › Ẩn/Hiện panel, Tạm dừng/Tiếp tục, Thoát | |
| Menu bar › **Cài đặt…** (⌘,) | Chỉnh độ mờ nền (0–100%), bật/tắt click xuyên qua (tắt để kéo panel), góc màn hình, độ rộng panel. Thay đổi áp dụng ngay và được lưu lại |

Trạng thái ở góc panel gồm: Đang chờ, Đang kiểm tra, Không có lỗi ngữ pháp, Có lỗi, Không phải tiếng Anh, Không chắc chắn (model muốn viết lại cả câu nên kết quả bị bỏ), Lỗi model.

## Giới hạn đã biết

- Chỉ kiểm tra **một câu** (câu chứa con trỏ), không kiểm tra cả đoạn. Câu dưới 3 từ và câu không phải tiếng Anh bị bỏ qua.
- Ô mật khẩu không bao giờ được đọc.
- Chrome và các app Electron (Slack, Teams) được bật cây accessibility tự động, nhưng mỗi app hỗ trợ một khác. Xem [docs/app-compatibility.md](docs/app-compatibility.md). App nào không đọc được thì dùng ⌃⌥G.
- Model vẫn có thể bỏ sót lỗi hoặc sửa hơi quá tay, ví dụ đổi "u" thành "you". Xem số liệu ở [docs/model-benchmark.md](docs/model-benchmark.md).

## Phát triển

```bash
# Unit test (test với model thật tự bỏ qua nếu chưa có model)
xcodebuild -project GrammarApp.xcodeproj -scheme GrammarApp -derivedDataPath build test

# Benchmark model trên golden set
xcodebuild -project GrammarApp.xcodeproj -scheme GrammarBench -configuration Release -derivedDataPath build build
./build/Build/Products/Release/GrammarBench --model GrammarApp/Resources/Models/Qwen2.5-7B-Instruct-Q4_K_M.gguf --verbose
```

Cấu trúc:

```
GrammarKit/     framework logic thuần: Diff (WordDiff, EditGuard, DiffHighlighter), Panel (PanelLayout, PanelSettings),
                Pipeline (SentenceExtractor, LanguageGate, CheckCoordinator, ResultCache),
                Engine (LlamaGrammarEngine, GrammarPrompt, OutputSanitizer, ModelLocator)
GrammarApp/     app: App (AppModel, menu bar, quyền), Capture (Accessibility, phím tắt), UI (panel)
GrammarAppTests/  unit test + Fixtures/golden.json
GrammarBench/   tool benchmark model
scripts/        fetch-llama.sh, download-model.sh
```

**Chẩn đoán khi app không đọc đúng câu đang gõ** (ví dụ trình soạn thảo web): chạy `swift scripts/ax-probe.swift <bundle-id>` (ví dụ `com.google.Chrome`), chuyển sang app đó và đặt con trỏ vào ô đang gõ. Script đọc 3 giây sau khi app đó được đưa lên trước. Script chỉ đọc, và in ra những gì app trả về qua Accessibility: vị trí con trỏ theo `AXSelectedTextRange` và đoạn văn đọc qua text marker. Với ô hỗ trợ text marker (Chrome, Safari, Electron), Grammar đọc đoạn văn chứa con trỏ qua text marker, vì `AXSelectedTextRange` có thể bị lệch so với `AXValue` trong trình soạn thảo có định dạng.

Model mặc định được khai báo ở `ModelLocator.defaultModelFileName`. Khi dev có thể chỉ định file model khác bằng biến môi trường `GRAMMAR_MODEL_PATH`.
