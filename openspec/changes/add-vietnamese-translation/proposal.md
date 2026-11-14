# Proposal

## Why

Người dùng chủ yếu là người Việt viết tiếng Anh. Sau khi thấy câu đã sửa, họ muốn chắc rằng câu đó nói đúng ý mình, nhưng hiện phải mở công cụ dịch khác, và việc đó vừa gián đoạn vừa gửi nội dung ra ngoài. Model Qwen2.5-7B mà app đã nạp sẵn dịch được tiếng Anh sang tiếng Việt, nên có thể thêm bản dịch ngay trên panel mà vẫn hoàn toàn offline.

## What Changes

- Panel có thêm section **"Bản dịch"** nằm dưới "Câu đã sửa". Section này chứa bản dịch tiếng Việt:
  - của câu đã sửa khi câu có lỗi,
  - của câu gốc khi câu đã đúng.
- Section chỉ hiện khi đã có kết quả sửa ("không có lỗi" hoặc "có lỗi"). Nó ẩn khi câu không phải tiếng Anh, kết quả không chắc chắn, model lỗi, đang chờ, đang nạp model hoặc đang kiểm tra.
- Bản dịch chạy sau bước sửa và không làm chậm việc hiện kết quả sửa. Trong lúc chờ, section hiện "Đang dịch…". Câu mới huỷ bản dịch cũ. Câu đã dịch được nhớ trong bộ nhớ để dùng lại.
- Màn hình **Cài đặt** có thêm công tắc **"Dịch sang tiếng Việt"**, **mặc định tắt**, áp dụng ngay và được lưu lại sau khi khởi động lại.
- Dịch bằng chính model đang chạy trên máy. Nội dung không gửi ra mạng, không ghi xuống đĩa.
- **Chỉ làm cho macOS.** Bản Windows (`windows/`) chưa có tính năng này và sẽ port sau.

## Capabilities

### New Capabilities
- `translation`: dịch câu đang kiểm tra sang tiếng Việt và hiển thị trên panel. Gồm: khi nào hiện bản dịch, dịch câu nào, chạy offline, không chặn kết quả sửa, huỷ và dùng lại bản dịch, công tắc bật/tắt trong Cài đặt cùng cách lưu.

### Modified Capabilities
- `checker-window`: requirement "Panel hai phần" ghi thêm rằng panel có thể có phần thứ ba "Bản dịch" khi tính năng Dịch bật. Công tắc trong Cài đặt được mô tả trong `translation`, không sửa requirement "Màn hình Cài đặt", để tránh đụng delta mà change `add-windows-app` đang sửa.

## Impact

- **Code macOS:**
  - `GrammarKit/Engine`: prompt dịch mới, protocol dịch, engine llama có thêm context thứ hai, sanitizer cho output dịch.
  - `GrammarKit/Pipeline/CheckCoordinator.swift`: trạng thái dịch, cache, huỷ.
  - `GrammarKit/Panel/PanelSettings.swift`: thêm cài đặt bật/tắt.
  - `GrammarApp/UI`: `TwoPaneView`, `SettingsView`.
  - `GrammarApp/App/AppModel.swift`: nối cài đặt vào coordinator.
  - `GrammarBench`: đo độ trễ dịch.
- **Bộ nhớ:** khi bật Dịch, tốn thêm khoảng 120 MB RAM cho KV cache của context dịch. Context này chỉ được tạo khi cần.
- **Độ trễ:** bước sửa giữ ngưỡng p95 ≤ 1.5 s như cũ. Bản dịch hiện sau đó, dự kiến chậm thêm 0.3–1 s mỗi câu (sẽ đo).
- **Không có dependency mới.** Không đổi code Windows.
- **Riêng tư:** giữ nguyên. Mọi xử lý nằm trong bộ nhớ của máy.
