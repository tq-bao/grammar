# Design

## Context

Lý do và phạm vi: xem proposal.md. Hành vi: xem `specs/model-download/spec.md` và các delta `specs/grammar-correction/spec.md`, `specs/checker-window/spec.md`.

Hiện trạng liên quan (macOS):
- `project.yml` copy nguyên thư mục `GrammarApp/Resources/Models` (git-ignore) vào `Contents/Resources/Models`. Mọi file `.gguf` trong thư mục này đều vào bundle. `scripts/install.sh` xoá các model không phải mặc định sau khi copy app.
- `ModelLocator.locate()` tìm model theo thứ tự env `GRAMMAR_MODEL_PATH` → bundle, không thấy thì throw `GrammarEngineError.modelNotFound`.
- `AppModel.loadEngine()` chạy trong `Task.detached`: locate → `LlamaGrammarEngine(modelURL:)` → `warmUp()` → `coordinator.setEngine(...)`. Lỗi thì gọi `setEngineError`.
- `CheckCoordinator` (`@MainActor @Observable`) đặt `state = .loadingModel` khi chưa có engine. Câu đến khi chưa có engine thì state trở thành `.loadingModel` hoặc `.modelError`. `StatusBadge` và `correctedContent` trong `TwoPaneView` switch trên `CheckState`, nên thêm case mới thì Swift bắt cập nhật cả hai.
- Panel cho click xuyên qua (chỉ header nhận chuột). Mọi hành động đều nằm ở menu bar, ví dụ "Cấp quyền Accessibility…", và `PermissionView` chỉ hướng dẫn người dùng ra menu bar.
- App ký bằng chứng chỉ tự ký để giữ quyền Accessibility. Ghi thêm file vào trong `.app` sẽ làm chữ ký không còn hợp lệ.
- File model hiện có: 4 683 074 240 byte, SHA256 `65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423`.

## Goals / Non-Goals

**Goals:**
- DMG dưới 100 MB.
- Downloader test được hoàn toàn bằng `URLProtocol` giả, không cần mạng thật hay file 4.7 GB.
- Dev và test không phải tải model qua app: `GrammarApp/Resources/Models/` và `GRAMMAR_MODEL_PATH` vẫn dùng được.
- Không đổi engine, prompt hay pipeline kiểm tra câu.

**Non-Goals:**
- Không port sang Windows.
- Không cho chọn model (3B/7B), và không quản lý nhiều model.
- Không có cơ chế cập nhật model (đổi phiên bản hay hash) ngoài việc phát hành bản app mới với hằng số mới.
- Không có mirror hay CDN riêng. Chỉ tải từ Hugging Face.
- Không có mục "Xoá model" trong UI. README hướng dẫn xoá thư mục bằng tay.
- Không tải ngầm khi app đã thoát (không dùng background `URLSession`).

## Decisions

### 1. Lưu model ở Application Support, không ghi vào bundle
- Đường dẫn: `FileManager.url(for: .applicationSupportDirectory, in: .userDomainMask)` + `Grammar/Models/<file>`. App không sandbox, nên đây là `~/Library/Application Support/Grammar/Models/`.
- **Đã cân nhắc:**
  - Ghi vào `Grammar.app/Contents/Resources/Models`: phá chữ ký code (mất quyền Accessibility), cần quyền ghi `/Applications`, và model mất mỗi lần cài lại.
  - `~/Library/Caches`: hệ thống hoặc công cụ dọn dẹp có thể xoá, dẫn tới phải tải lại 4.7 GB.

### 2. `ModelLocator`: env → Application Support → bundle
- Thêm tham số `applicationSupportDirectory: URL?` (mặc định là thư mục thật) vào `locate`, để test truyền được thư mục tạm.
- Thêm hàm `downloadDestination()` trả về URL đích để downloader và `install.sh` dùng chung một quy ước.
- Giữ fallback bundle: chỉ vài dòng, giúp build bản "đầy đủ offline" khi cần (đặt model lại vào bundle bằng tay), và test hiện có đang dùng tham số `bundle:`.
- Thêm các hằng số tải vào `ModelLocator` (đặt cùng `defaultModelFileName` để chỉ có một chỗ khai báo):
  - `defaultModelURL`: `https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf`
  - `defaultModelSHA256`
  - `defaultModelSize`
- Có thể ghim theo commit thay cho `main` nếu lấy được revision hash khi triển khai. Checksum vẫn là lớp bảo vệ chính.

### 3. `ModelDownloader`: tự stream ra file `.part` bằng header `Range`
- Một `actor` trong GrammarKit, nhận `URLSession` qua init (test inject session có `URLProtocol` giả).
- **Các bước:**
  1. Tạo thư mục đích. Đọc kích thước `<file>.part` hiện có, gọi là `offset`.
  2. Kiểm tra dung lượng trống: `volumeAvailableCapacityForImportantUsageKey` phải lớn hơn hoặc bằng `size − offset + 512 MB`. Không đủ thì throw `.insufficientDiskSpace(required:)`.
  3. Gửi request GET kèm `Range: bytes=<offset>-` (khi `offset > 0`), dùng `session.bytes(for:)`.
     - Trả `206`: append vào `.part`.
     - Trả `200` (server không hỗ trợ Range): ghi đè `.part` từ đầu.
     - Mã khác: throw `.http(status)`.
  4. Ghi theo khối (khoảng 1 MB buffer qua `FileHandle`). Phát tiến độ qua closure `@Sendable (Int64, Int64) -> Void`, giới hạn khoảng 10 lần mỗi giây. Kiểm tra `Task.isCancelled` sau mỗi khối.
  5. Xong thì kiểm tra kích thước, magic `GGUF` và SHA256 (`CryptoKit.SHA256`, đọc file theo khối 8 MB).
     - Sai: xoá `.part` và throw `.checksumMismatch`.
     - Đúng: `moveItem` từ `.part` sang tên thật. Hai file cùng thư mục nên phép move là atomic.
- Huỷ (cancel Task) giữ nguyên `.part`, để lần sau tải tiếp.
- **Đã cân nhắc:**
  - `URLSessionDownloadTask` với `resumeData`: resumeData chỉ có khi huỷ "êm". Nếu app bị kill hoặc crash thì mất, lại phải tải từ đầu 4.7 GB. File tạm cũng nằm trong thư mục hệ thống quản lý.
  - Background `URLSession`: tải được khi app đã thoát, nhưng phức tạp (delegate, khôi phục session) mà không cần cho app menu bar luôn chạy.
- Kiểm tra SHA256 trên 4.7 GB mất vài giây. Lúc này panel hiện "Đang kiểm tra model…", được biểu diễn là tiến độ 100% với nhãn khác.

### 4. Trạng thái model tách khỏi trạng thái kiểm tra câu
- Thêm vào `CheckState`:
  - `.modelMissing`
  - `.downloadingModel(received: Int64, total: Int64)`
  - `.verifyingModel`, nếu thấy gọn hơn. Nếu không thì gộp vào `.downloadingModel` khi `received == total`.
- `CheckCoordinator` thay `engineError: String?` bằng `unavailableState: CheckState` (mặc định `.loadingModel`). Giá trị này là trạng thái hiển thị khi chưa có engine. Các API mới:
  - `setModelMissing()`
  - `setModelDownloadProgress(received:total:)`
  - `setEngineError(_:)` (giữ nguyên chữ ký)
  - `setLoadingModel()`
- `run()` đang có `state = engineError.map(...) ?? .loadingModel`. Đổi thành `state = unavailableState`. Vì vậy câu gõ khi đang tải không đè mất thanh tiến độ, và không gọi engine.
- So sánh `state != .loadingModel` trong `submit` mở rộng thành "không phải trạng thái chưa có engine".
- **Đã cân nhắc:** giữ trạng thái tải ở `AppModel` và để `TwoPaneView` tự ưu tiên hiển thị. Cách này làm logic hiển thị tách khỏi coordinator, khó test bằng unit test.

### 5. Luồng UI trong `AppModel`
- `AppModel` có `modelStatus` (observable), là enum:
  - `.ready`
  - `.loading`
  - `.missing(partialBytes: Int64)`
  - `.downloading(received, total)`
  - `.failed(String)`
- Menu bar đọc giá trị này để hiện:
  - "Tải model (4.7 GB)…" hoặc "Tải tiếp model (còn x GB)…"
  - "Đang tải model… 37%" (disabled) cùng "Huỷ tải"
  - "Thử lại tải model"
- `start()` → `loadEngine()`:
  - Locate thấy model: chạy như cũ.
  - Không thấy (`modelNotFound`): `coordinator.setModelMissing()`, rồi `promptForDownload()`. Hàm này gọi `NSApp.activate()` và chạy `NSAlert` modal với hai nút "Tải ngay" và "Để sau". Alert ghi rõ dung lượng, nơi lưu, và việc sau đó app chạy offline.
- `downloadModel()` giữ `downloadTask: Task`:
  - Tiến độ được đưa về `@MainActor` để cập nhật cả `modelStatus` lẫn coordinator.
  - Thành công: gọi lại `loadEngine()`.
  - Lỗi: `coordinator.setEngineError(message)` và `modelStatus = .failed`.
  - Huỷ: quay về `.missing`.
- Alert chạy sau khi panel đã hiện, nên người dùng thấy panel báo "Cần tải model" phía sau.
- Chỉ hỏi lại ở lần khởi động sau. Không hỏi lặp lại trong cùng phiên.
- **Đã cân nhắc:** một cửa sổ onboarding riêng bằng SwiftUI. Đẹp hơn nhưng nhiều code hơn. `NSAlert` cùng menu bar khớp với phong cách tối giản hiện có.

### 6. Build và phân phối
- `project.yml`: bỏ khối `- path: GrammarApp/Resources/Models / type: folder / buildPhase: resources`. Giữ `excludes` để Xcode không nhặt file `.gguf` làm resource.
- `scripts/install.sh`:
  - Bỏ điều kiện bắt buộc có model và bỏ lệnh `find … -delete`.
  - Nếu `GrammarApp/Resources/Models/<default>` có mà `~/Library/Application Support/Grammar/Models/<default>` chưa có, thì `cp -c` (clone APFS, gần như tức thì và không tốn thêm chỗ), fallback `cp`.
- `scripts/make-dmg.sh` (mới):
  1. Build Release giống `install.sh`.
  2. Copy app sang staging và ký. Phần ký được tách thành `scripts/lib/sign.sh` để dùng chung.
  3. Tạo symlink `/Applications`.
  4. `hdiutil create -volname Grammar -srcfolder <staging> -format UDZO -ov dist/Grammar-<CFBundleShortVersionString>.dmg`.
  5. Cảnh báo nếu bundle có chứa `.gguf`.
- `.gitignore`: thêm `dist/`.

### 7. Test
- `ModelLocatorTests`: ưu tiên Application Support hơn bundle, env ưu tiên cao nhất, không thấy thì throw.
- `ModelDownloaderTests`, dùng `URLProtocol` giả phục vụ file nhỏ (khoảng 64 KB, bắt đầu bằng `GGUF`) cùng hash tương ứng. Downloader nhận `expectedSize`/`sha256` qua init nên không phụ thuộc hằng số thật. Các trường hợp:
  - tải đủ
  - resume: kiểm tra header `Range` và nội dung ghép đúng
  - server trả 200 khi đã có `.part`
  - sai hash: `.part` bị xoá
  - HTTP 404
  - thiếu dung lượng: inject closure trả dung lượng trống
  - huỷ: `.part` còn lại
- `CheckCoordinator`: `submit` khi `.modelMissing` hoặc `.downloadingModel` thì giữ nguyên state và không gọi engine. Tải xong, `setEngine` kiểm tra câu đang chờ.

## Risks / Trade-offs

- [Hugging Face đổi đường dẫn, xoá repo hoặc thay file] → Checksum ghim làm việc tải thất bại rõ ràng thay vì nạp file lạ. Sửa bằng cách phát hành bản app mới với URL hoặc hash mới. Có thể ghim revision commit trong URL để tránh file bị thay.
- [Mạng công ty chặn `huggingface.co` hoặc dùng proxy SSL] → `URLSession` dùng proxy hệ thống. Panel báo lỗi kèm lý do. README hướng dẫn cách thủ công: tải file rồi đặt vào thư mục Application Support, app nhận ra ở lần mở sau.
- [Tải 4.7 GB lâu, người dùng tưởng app treo] → Panel và menu bar có tiến độ, alert ghi rõ dung lượng. Có tải tiếp và có huỷ.
- [Ổ đầy giữa chừng] → Kiểm tra trước khi tải, cộng 512 MB dự phòng. Nếu ghi vẫn lỗi thì throw lỗi rõ ràng và giữ `.part`.
- [Hash 4.7 GB tốn vài giây CPU] → Chạy ngoài main actor, panel hiện "Đang kiểm tra model…". Chỉ chạy một lần.
- [Dev quen build là có model trong app] → `install.sh` tự copy model local sang Application Support. README ghi rõ. Test và bench vẫn đọc `GrammarApp/Resources/Models/`.
- [Hai bản app cùng chạy và cùng ghi `.part`] → App menu bar chạy một bản (LSUIElement, mở lại thì kích hoạt bản đang chạy). Chấp nhận rủi ro còn lại, vì checksum sẽ bắt file hỏng.
- [`CheckState` của Windows lệch với macOS] → Windows không có tính năng này. Không port case mới, và ghi điều này trong tasks.

## Migration Plan

- Người đã cài bản cũ (model nằm trong bundle): bản mới không còn model trong bundle, nên lần mở đầu sẽ hỏi tải. Muốn tránh tải lại thì trước khi cài đè, copy `Grammar.app/Contents/Resources/Models/*.gguf` sang `~/Library/Application Support/Grammar/Models/`. README ghi bước này. `install.sh` tự làm việc đó nếu có model trong repo.
- Rollback: khôi phục khối folder resource trong `project.yml`. Locator vẫn đọc bundle nên app chạy lại như cũ.

## Open Questions

- Ghim URL theo revision commit của repo Hugging Face hay để `main`: chọn khi triển khai, sau khi kiểm tra header `x-linked-etag` hoặc `X-Repo-Commit` khớp với hash đã ghim. Lựa chọn này không đổi spec hay task.
