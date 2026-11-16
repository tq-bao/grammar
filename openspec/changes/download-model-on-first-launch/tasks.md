# Tasks

Ghi chú: change này chỉ sửa code macOS. Không port `CheckState` mới sang Windows. Lệnh test dùng chung: `xcodegen generate && xcodebuild test -project GrammarApp.xcodeproj -scheme GrammarApp -derivedDataPath build`.

## 1. Tìm model: ModelLocator

- [x] 1.1 Đối chiếu SHA256 `65b8fcd9…1423` và kích thước 4 683 074 240 byte với file trên Hugging Face: xem header `x-linked-etag` hoặc `x-linked-size` của `curl -sI` tới URL tải. Quyết định ghim URL theo `main` hay theo revision commit (design, Open Questions). Kiểm tra: hai giá trị khớp. Ghi revision (nếu ghim) vào comment cạnh hằng số.
- [x] 1.2 Trong `GrammarKit/Engine/ModelLocator.swift`, thêm:
  - các hằng số `defaultModelURL`, `defaultModelSHA256`, `defaultModelSize`
  - hàm `applicationSupportModelsDirectory()` và `downloadDestination()`
  - tham số `applicationSupportDirectory:` cho `locate`

  Thứ tự tìm là env → Application Support → bundle (design §1–2). Kiểm tra: thêm test trong `GrammarAppTests/EngineTests.swift`:
  - Application Support được ưu tiên hơn bundle
  - env được ưu tiên nhất
  - không có ở đâu thì ném `modelNotFound`

  Test cũ vẫn pass.

## 2. Tải model: ModelDownloader

- [x] 2.1 Tạo `GrammarKit/Engine/ModelDownloader.swift` (actor) theo design §3. Actor nhận `URLSession`, URL, đích, `expectedSize`, `sha256`, và closure đọc dung lượng trống (để test inject). Việc tải:
  - ghi vào `<file>.part`, có header `Range` khi đã có `.part`
  - xử lý được 206, 200 và mã lỗi
  - phát tiến độ khoảng 10 lần mỗi giây
  - kiểm tra `Task.isCancelled` sau mỗi khối

  Thêm `ModelDownloadError` (`insufficientDiskSpace(required:)`, `http(Int)`, `checksumMismatch`, `notGGUF`, `sizeMismatch`), có `errorDescription` tiếng Việt. Kiểm tra: build pass.
- [x] 2.2 Bước hoàn tất: kiểm tra kích thước, magic `GGUF`, SHA256 (CryptoKit, đọc theo khối 8 MB), rồi `moveItem` từ `.part` sang tên thật. Sai thì xoá `.part`. Có callback báo đang kiểm tra. Kiểm tra: test ở 2.3.
- [x] 2.3 Viết `GrammarAppTests/ModelDownloaderTests.swift`, dùng `URLProtocol` giả phục vụ file khoảng 64 KB bắt đầu bằng `GGUF`. Các trường hợp, mỗi cái ứng với một scenario của `model-download`:
  - tải đủ thì có file thật và không còn `.part`
  - resume: request có `Range: bytes=N-`, file ghép đúng hash
  - server trả 200 khi đã có `.part` thì ghi lại từ đầu
  - sai hash thì ném `checksumMismatch` và xoá `.part`
  - 404 thì ném `http(404)`
  - thiếu dung lượng thì ném lỗi và không có request nào được gửi
  - huỷ giữa chừng thì `.part` còn lại
  - request chỉ gồm GET tới URL đã định, không có body

  Kiểm tra: test pass.

## 3. Trạng thái model trong CheckCoordinator

- [x] 3.1 Trong `GrammarKit/Pipeline/CheckCoordinator.swift`:
  - Thêm vào `CheckState`: `.modelMissing`, `.downloadingModel(received: Int64, total: Int64)` và `.verifyingModel`.
  - Thay `engineError` bằng `unavailableState`.
  - Thêm `setModelMissing()`, `setModelDownloadProgress(received:total:)`, `setVerifyingModel()` và `setLoadingModel()`.
  - `run()` dùng `unavailableState` khi chưa có engine.
  - `submit` coi mọi trạng thái chưa có engine giống `.loadingModel`.

  Thiết kế theo design §4. Kiểm tra: build pass, test cũ trong `PipelineTests.swift` vẫn pass.
- [x] 3.2 Thêm test vào `GrammarAppTests/PipelineTests.swift`:
  - `submit` khi `.modelMissing` hoặc `.downloadingModel` thì giữ nguyên state, `engineCallCount == 0`
  - `setEngine` sau khi tải xong thì kiểm tra câu đang chờ
  - `setEngineError` sau khi đang tải thì ra `.modelError`

  Kiểm tra: test pass.
- [x] 3.3 Cập nhật `GrammarApp/UI/TwoPaneView.swift` (`correctedContent` và `StatusBadge`):
  - "Cần tải model": hướng dẫn mở menu bar › "Tải model…", theo kiểu `PermissionView`.
  - "Đang tải model": có `ProgressView` kèm phần trăm cạnh thanh, không hiện dung lượng model.
  - "Đang kiểm tra model…"
  - Icon và màu phù hợp.

  Kiểm tra: build pass. Xem bằng mắt ở bước 6.2.

## 4. Luồng hỏi và tải trong app

- [x] 4.1 Trong `GrammarApp/App/AppModel.swift`, thêm `modelStatus` (`ready`, `loading`, `missing(partialBytes)`, `downloading(received,total)`, `verifying`, `failed(String)`). Tách `loadEngine()`:
  - Locate thấy model: nạp như cũ.
  - `modelNotFound`: gọi `coordinator.setModelMissing()` rồi `promptForDownload()`.

  Thiết kế theo design §5. Kiểm tra: build pass. Với model ở Application Support, app nạp như cũ và không có alert.
- [x] 4.2 `promptForDownload()`: gọi `NSApp.activate()` rồi hiện `NSAlert`.
  - Nội dung: nơi lưu, chỉ tải một lần, sau đó chạy offline (hoặc "đã tải được x%" nếu có `.part`). Không nêu dung lượng model.
  - Hai nút "Tải ngay" và "Để sau".

  Kiểm tra: xoá model, mở app thì thấy alert. Chọn "Để sau" thì không có request mạng và panel báo "Cần tải model".
- [x] 4.3 `downloadModel()` và `cancelDownload()`:
  - Chạy `ModelDownloader` trong `Task`, tiến độ được đưa về main actor để cập nhật `modelStatus` và coordinator.
  - Thành công thì gọi lại `loadEngine()`.
  - Lỗi thì gọi `setEngineError` và đặt `.failed`.
  - Huỷ thì quay về `.missing`.

  Kiểm tra: tải thật xong thì kiểm tra được "They was happy." mà không cần khởi động lại.
- [x] 4.4 Trong `GrammarApp/App/GrammarApp.swift` › `MenuBarContent`, thêm các mục theo `modelStatus`:
  - "Tải model…" hoặc "Tải tiếp model (đã tải x%)…"
  - "Đang tải model… x%" (disabled) cùng "Huỷ tải"
  - "Thử lại tải model"
  - Ẩn hết khi `ready` hoặc `loading`.

  Kiểm tra: xem menu ở từng trạng thái (bước 6.2).

## 5. Build, script và tài liệu

- [x] 5.1 Trong `project.yml`, bỏ folder resource `GrammarApp/Resources/Models`, giữ `excludes`. Thêm `dist/` vào `.gitignore`. Kiểm tra: chạy `xcodegen generate` rồi build Release, thì `find build/Build/Products/Release/Grammar.app -name '*.gguf'` không ra gì.
- [x] 5.2 Sửa `scripts/install.sh`:
  - Bỏ điều kiện bắt buộc có model và bỏ lệnh `find … -delete`.
  - Copy hoặc clone (`cp -c`) model từ `GrammarApp/Resources/Models/` sang Application Support nếu bên đó chưa có.
  - Tách phần ký sang `scripts/lib/sign.sh`.

  Kiểm tra: `./scripts/install.sh` chạy xong, app mở không có alert, và model có ở Application Support.
- [x] 5.3 Thêm `scripts/make-dmg.sh` theo design §6. Script build Release, staging, ký (dùng `scripts/lib/sign.sh`), tạo symlink `/Applications`, chạy `hdiutil create … UDZO`, ra `dist/Grammar-<version>.dmg`, và cảnh báo nếu bundle có `.gguf`. Kiểm tra: `du -h dist/*.dmg` nhỏ hơn 100 MB, mount DMG thấy `Grammar.app` và lối tắt Applications.
- [x] 5.4 Cập nhật `README.md`:
  - Mục Build: model không còn bắt buộc. `download-model.sh` chỉ dành cho dev, test và bench.
  - Thêm mục "Lần chạy đầu: tải model": dung lượng, nơi lưu, tải tiếp, cách tải tay khi mạng chặn, cách xoá.
  - Mục tạo DMG.
  - Câu về quyền riêng tư: chỉ tải model một lần, không gửi nội dung đã gõ.
  - Bước chuyển từ bản cũ (copy model từ bundle cũ sang).

  Kiểm tra: làm theo đúng các lệnh trong README trên máy sạch thì chạy được.

## 6. Kiểm tra tích hợp

- [x] 6.1 Chạy toàn bộ unit test. Kiểm tra: `xcodebuild test` pass, kể cả test engine thật khi có model ở `GrammarApp/Resources/Models/`.
- [ ] 6.2 Kiểm tra bằng tay end-to-end với bản cài từ DMG. Trước khi làm, đổi tên tạm `~/Library/Application Support/Grammar`.
  - Thấy alert khi mở app.
  - "Để sau": panel báo cần tải, menu có mục tải.
  - Tải: tiến độ hiện trên panel và menu.
  - Tắt Wi-Fi giữa chừng: báo lỗi và có mục thử lại.
  - Thoát rồi mở lại: alert ghi "đã tải được x%", và tải tiếp từ chỗ cũ.
  - Tải xong: hiện "Đang kiểm tra model…", rồi kiểm tra được câu.
  - Tắt mạng: vẫn sửa được "They was happy."

  Kiểm tra: mọi bước đúng như các scenario trong `specs/model-download/spec.md` và `specs/checker-window/spec.md`.
- [x] 6.3 `openspec validate download-model-on-first-launch --strict` pass.

## Workflow follow-up

- Archive change sau khi review xong. Khi archive, lưu ý `add-windows-app` cũng sửa requirement "Sửa ngữ pháp offline": archive change nào sau thì phải kiểm tra lại câu chữ cuối cùng của requirement này trong `openspec/specs/grammar-correction/spec.md`.
