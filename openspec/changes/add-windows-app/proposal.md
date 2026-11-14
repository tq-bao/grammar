# Proposal

## Why

Grammar hiện chỉ chạy trên macOS. Người dùng cần dùng cùng chức năng trên một máy Windows cá nhân: kiểm tra ngữ pháp offline câu đang gõ ở app khác, panel trong suốt click xuyên qua, câu sửa copy được. Cấu hình máy Windows (CPU, GPU, RAM) chưa biết trước, và hiện chưa có máy để test. Vì vậy phần lớn việc kiểm chứng phải làm được ngay trên Mac.

## What Changes

- Thêm **app Windows** viết bằng C# trên .NET 10 (LTS) và WPF, đặt trong thư mục `windows/` của repo. Code macOS giữ nguyên.
- Port toàn bộ logic thuần của `GrammarKit` sang thư viện `Grammar.Core` đa nền tảng, gồm diff, EditGuard, normalizer, pipeline, cache, bố cục panel và golden set. Test của thư viện này chạy được trên Mac bằng `dotnet test`.
- **Tách câu và nhận diện tiếng Anh/tiếng Việt** được viết lại, vì thư viện NaturalLanguage của Apple không có trên Windows. Hành vi vẫn phải đạt đúng các scenario hiện có trong spec.
- Engine dùng llama.cpp qua LLamaSharp và chạy cùng model GGUF như bản Mac. App ưu tiên GPU qua Vulkan, không được thì tự chuyển sang CPU. Riêng bản Windows có thêm mục chọn model trong Cài đặt, để máy yếu dùng được model nhỏ hơn.
- Đọc ô đang gõ bằng **UI Automation** của Windows. Windows không yêu cầu cấp quyền như Accessibility trên macOS.
- Menu bar của macOS được thay bằng **icon ở khay hệ thống**. App không có nút trên taskbar.
- **Bản Windows không có phím tắt toàn cục.** Không có `⌃⌥C`; copy câu sửa qua menu khay. Cũng **không có cách dự phòng bôi đen rồi bấm phím tắt** (`⌃⌥G`): app nào không đọc được qua UI Automation thì không kiểm tra được.
- Panel, Cài đặt và cách lưu cài đặt giống bản Mac: trong suốt, click xuyên qua, kéo bằng header, chọn góc, độ rộng, vị trí đã kéo.
- Đóng gói thành file zip self-contained win-x64, giải nén ra là chạy được, không cần cài .NET. File model tải riêng. Build zip được ngay trên Mac.
- Thêm tool `Grammar.Bench` để đo độ chính xác và độ trễ trên golden set, và tool `Grammar.Probe` để dò xem một app trả về gì qua UI Automation.

## Capabilities

### New Capabilities
<!-- Không có. Bản Windows thực hiện cùng các capability hiện có, khác biệt theo nền tảng được ghi trong delta spec. -->

### Modified Capabilities
- `text-capture`: thêm cách đọc ô qua UI Automation trên Windows. Requirement cấp quyền Accessibility và phím tắt kiểm tra đoạn bôi đen chỉ áp dụng cho macOS. Thêm giới hạn của Windows: không đọc được app đang chạy quyền admin.
- `checker-window`: trên Windows, menu bar được thay bằng khay hệ thống, không có phím tắt `⌃⌥C` hay `⌘,`, "không có icon Dock" thành "không có nút trên taskbar", và vùng hiển thị là vùng không bị taskbar che.
- `grammar-correction`: ngưỡng độ trễ phân theo nền tảng và theo việc có GPU hay không. Thêm requirement chọn GPU, dự phòng CPU và chọn model trên Windows. Nhận diện ngôn ngữ phải cho kết quả giống nhau trên cả hai nền tảng.

## Impact

- **Code mới** trong `windows/`: `Grammar.Core`, `Grammar.Engine`, `Grammar.App` (WPF), `Grammar.Bench`, `Grammar.Probe`, các project test, script build và tải model.
- **Không đổi code macOS.** `GrammarAppTests/Fixtures/golden.json` được dùng chung, phía Windows đọc thẳng file này.
- **Dependency mới**: .NET 10 SDK trên máy dev, các gói NuGet LLamaSharp (cùng backend CPU, Vulkan và Metal để chạy test trên Mac), interop UIAutomationClient, xUnit.
- **Rủi ro chưa kiểm chứng được**: không có máy Windows nên chưa biết Chrome, Slack, Teams có trả về text qua UI Automation không, và chưa biết độ trễ thật. Có checklist test tay và `Grammar.Probe` cho lúc có máy.
- **Bảo trì**: logic tồn tại hai bản (Swift và C#). Sửa prompt, EditGuard hay normalizer phải sửa ở cả hai nơi. Golden set dùng chung để phát hiện lệch.
- **Riêng tư**: giữ nguyên. Nội dung chỉ xử lý trong bộ nhớ, không gửi ra mạng, không ghi xuống đĩa.
