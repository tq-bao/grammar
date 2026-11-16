# Proposal

## Why

File cài `Grammar-1.0.dmg` nặng 4.6 GB. Gần như toàn bộ dung lượng là model `Qwen2.5-7B-Instruct-Q4_K_M.gguf` (4.68 GB), đang được copy vào `Grammar.app/Contents/Resources/Models`. File cài to như vậy thì khó chia sẻ, khó tải và khó cập nhật app: mỗi lần sửa một dòng code, người dùng lại phải tải lại cả model. Nếu tách model khỏi app và tải model một lần ở lần mở đầu tiên, DMG chỉ còn vài chục MB, và các bản cập nhật sau không phải tải lại model.

## What Changes

- **BREAKING (đóng gói):** app macOS không còn chứa model. `project.yml` bỏ việc copy `GrammarApp/Resources/Models` vào bundle. Thư mục này vẫn là nơi để model khi dev, test và benchmark.
- Model được lưu ở `~/Library/Application Support/Grammar/Models/`, nằm ngoài `.app`, nên không làm hỏng chữ ký code và còn nguyên khi cài lại hay cập nhật app.
- **Lần mở đầu tiên khi chưa có model:**
  - App hiện hộp thoại hỏi có tải model ~4.7 GB không, với hai lựa chọn "Tải ngay" và "Để sau".
  - Nếu chọn "Để sau": panel báo cần tải model, và menu bar có mục "Tải model (4.7 GB)…".
- **Khi tải:**
  - Panel và menu bar hiện tiến độ. Menu bar có mục "Huỷ tải".
  - Tải tiếp được sau khi mất mạng hoặc thoát app.
  - Trước khi tải, app kiểm tra dung lượng ổ trống.
  - Tải xong, app kiểm tra file là GGUF và đúng SHA256 đã ghim, rồi mới nạp model.
  - Lỗi thì báo rõ ràng và cho thử lại.
- Sau khi đã có model, app chạy offline hoàn toàn như hiện nay. Việc tải chỉ gửi một request tải file tới Hugging Face, **không bao giờ gửi nội dung người dùng gõ**.
- `ModelLocator` tìm model theo thứ tự: biến môi trường `GRAMMAR_MODEL_PATH` → Application Support → bundle. Giữ fallback bundle để vẫn build được bản offline đầy đủ khi cần.
- **Script:**
  - `scripts/install.sh` không còn bắt buộc có model. Nếu có sẵn model local thì copy model sang Application Support để không phải tải lại.
  - Thêm `scripts/make-dmg.sh` để tạo DMG.
- README cập nhật phần Build, thêm mục lần chạy đầu và cập nhật câu nói về quyền riêng tư.
- **Chỉ macOS, chỉ model 7B.** Bản Windows giữ cách đặt model vào thư mục `Models` như hiện tại.

## Capabilities

### New Capabilities
- `model-download`: tải model ngôn ngữ về máy ở lần mở đầu tiên trên macOS. Gồm hỏi người dùng trước khi tải, nơi lưu model, mục menu bar để tải, xem tiến độ và huỷ, tải tiếp sau khi bị ngắt, kiểm tra dung lượng trống và checksum, xử lý lỗi và thử lại, và cam kết không gửi nội dung người dùng gõ khi tải.

### Modified Capabilities
- `grammar-correction`: requirement "Sửa ngữ pháp offline".
  - Trên macOS, model không còn "đóng gói kèm app" mà được tải một lần rồi lưu trên máy.
  - App MUST chạy được khi không có mạng sau khi đã có model.
  - Thêm scenario khi chưa có model.
  - Change `add-windows-app` cũng sửa requirement này. Delta lần này dựa trên câu chữ của change đó và giữ nguyên phần về Windows.
- `checker-window`: requirement "Trạng thái kiểm tra" thêm hai trạng thái "Cần tải model" và "Đang tải model" (kèm tiến độ).

## Impact

- **Code macOS:**
  - `GrammarKit/Engine/ModelLocator.swift`: thêm Application Support và các hằng số tải.
  - `GrammarKit/Engine/ModelDownloader.swift` (mới).
  - `GrammarKit/Pipeline/CheckCoordinator.swift`: thêm trạng thái mới.
  - `GrammarApp/App/AppModel.swift`: luồng hỏi, tải rồi nạp model.
  - `GrammarApp/App/GrammarApp.swift`: các mục menu bar.
  - `GrammarApp/UI/TwoPaneView.swift`: hiển thị trạng thái và tiến độ.
- **Build và phân phối:**
  - Sửa `project.yml` và `scripts/install.sh`.
  - Thêm `scripts/make-dmg.sh`.
  - `.gitignore` thêm `dist/`.
- **Test:** test mới cho `ModelLocator` và `ModelDownloader` (`URLProtocol` giả). Thêm test trạng thái cho `CheckCoordinator`.
- **Dependency:** không thêm. Dùng `URLSession` và `CryptoKit` có sẵn trong hệ thống.
- **Mạng:** cần Internet một lần để tải khoảng 4.7 GB từ `huggingface.co`. Nếu Hugging Face đổi URL hoặc file, việc tải sẽ lỗi. Checksum đã ghim đảm bảo app không nạp file khác.
- **Không đổi:** code Windows, engine, prompt, cách sửa và dịch câu.
