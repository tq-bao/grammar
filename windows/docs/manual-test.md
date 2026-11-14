# Checklist test tay trên Windows

Các phần không gắn với Windows (diff, tách câu, nhận diện ngôn ngữ, pipeline, engine, golden set) đã có unit test, chạy được trên Mac bằng `dotnet test windows/Grammar.sln`. Checklist này chỉ phủ những thứ phải chạy trên máy Windows thật: đọc ô qua UI Automation, panel, khay hệ thống, cài đặt và đóng gói.

Mỗi dòng ứng với một scenario trong spec của change `add-windows-app` (`openspec/changes/add-windows-app/specs/`) hoặc spec gốc.

**Cách ghi kết quả:** đánh `x` vào ô khi pass. Nếu fail thì ghi ngắn hiện tượng ở cột Ghi chú, và mở task hoặc issue tiếp theo.

Máy test: Windows ____ (build ____), CPU ____, GPU ____, RAM ____ GB, scale màn hình ____%.

## 0. Khởi động

| | Kiểm tra | Cách làm | Mong đợi | Ghi chú |
|---|---|---|---|---|
| [ ] | Khởi động không treo | Giải nén zip, đặt model vào `Models\`, chạy `Grammar.exe` | Có icon khay, panel hiện ở góc trên phải. Mở Task Manager: CPU của Grammar về gần 0% sau khi nạp model xong | |
| [ ] | SmartScreen | Lần chạy đầu | Nếu có cảnh báo, chọn "More info" rồi "Run anyway" thì app chạy | |

## 1. Đọc ô đang gõ (spec text-capture)

| | Scenario | Cách làm | Mong đợi | Ghi chú |
|---|---|---|---|---|
| [ ] | Gõ trong app gốc của Windows | Gõ "She go to school yesterday." vào Notepad, dừng 1 giây | Panel hiện câu, gạch chân "go", câu sửa "She went to school yesterday." | |
| [ ] | Chuyển sang ô khác | Gõ ở Notepad, rồi click sang một ô khác (ví dụ ô tìm kiếm của Edge) và gõ câu khác | Panel theo ô mới, không còn dùng nội dung ô cũ | |
| [ ] | Ô nhiều câu | Trong Notepad gõ "I like tea. He have two cats. We are fine." rồi đặt con trỏ vào câu thứ hai | Panel kiểm tra "He have two cats." | |
| [ ] | Ô mật khẩu | Gõ vào ô mật khẩu (ví dụ trang đăng nhập trên Edge) | Panel không hiện gì từ ô đó | |
| [ ] | Cửa sổ của chính app | Mở Cài đặt của Grammar, click vào thanh trượt | Panel giữ nguyên nội dung cũ | |
| [ ] | App chạy quyền quản trị | Mở Notepad bằng "Run as administrator", gõ "this are wrong" | Panel giữ nguyên, không báo lỗi, Grammar vẫn chạy | |
| [ ] | Quay lại app thường | Sau đó gõ trong một Notepad thường | Đọc được như bình thường | |
| [ ] | Không có phím tắt | Bôi đen một đoạn rồi bấm Ctrl+Alt+G, Ctrl+Alt+C | Grammar không phản ứng, clipboard và panel không đổi, phím vẫn đến app đang gõ | |
| [ ] | Không cần cấp quyền | Lần chạy đầu | Không có hướng dẫn cấp quyền, menu khay không có mục cấp quyền, app theo dõi ngay | |
| [ ] | Tạm dừng | Menu khay, chọn "Tạm dừng", rồi gõ trong Notepad | Panel không cập nhật. Chọn "Tiếp tục" thì cập nhật lại | |

### Tương thích từng app

Dùng `Grammar.Probe.exe` (nằm cạnh `Grammar.exe`, xem `windows/README.md`) để xem app trả về gì qua UI Automation. Ghi kết quả vào `docs/app-compatibility.md`, mục Windows.

| | App | Đọc được câu đang gõ? | Đúng câu chứa con trỏ? | Ghi chú (pattern nào: TextPattern2 / TextPattern / Value) |
|---|---|---|---|---|
| [ ] | Notepad | | | |
| [ ] | Word | | | |
| [ ] | Outlook (soạn thư) | | | |
| [ ] | Chrome: Gmail | | | |
| [ ] | Chrome: Confluence (trang dài, có code inline) | | | |
| [ ] | Edge | | | |
| [ ] | Slack | | | |
| [ ] | Teams | | | |

## 2. Panel (spec checker-window)

| | Scenario | Cách làm | Mong đợi | Ghi chú |
|---|---|---|---|---|
| [ ] | Panel hai phần, gạch chân, tô xanh | Gõ "He have two cats." trong Notepad | Phần trên gạch đỏ "have", phần dưới tô xanh đậm "has" | |
| [ ] | Thiếu từ | Gõ "I going home." | Khoảng trắng giữa "I" và "going" có nền đỏ nhạt, gạch đỏ | |
| [ ] | Trạng thái | Lần lượt: câu đúng, câu tiếng Việt, câu đang kiểm tra | "Không có lỗi ngữ pháp", "Không phải tiếng Anh", "Đang kiểm tra" | |
| [ ] | Panel không lấy focus | Gõ liên tục trong Notepad trong lúc panel cập nhật | Con trỏ vẫn ở Notepad, gõ tiếp bình thường | |
| [ ] | Click xuyên qua | Đặt panel đè lên ô văn bản của Notepad, click vào vùng panel ở đúng chỗ đó | Con trỏ vào Notepad, panel không phản ứng | |
| [ ] | Cuộn xuyên qua | Cuộn chuột trên panel đang đè lên một trang web | Trang web phía sau cuộn | |
| [ ] | Kéo header | Nhấn giữ header (≡ Grammar) kéo panel ra giữa màn hình | Panel di chuyển, Notepad vẫn giữ focus bàn phím (gõ tiếp được ngay) | |
| [ ] | Header không cho click xuyên | Click vào header đang đè lên một nút của app phía sau | Nút phía sau không nhận click | |
| [ ] | Phần dưới header vẫn xuyên qua | Click ngay dưới header | Click đi xuống cửa sổ phía sau | |
| [ ] | Nền 50% | Cài đặt, độ mờ 50% | Thấy nội dung phía sau, chữ vẫn rõ | |
| [ ] | Nền 0% | Độ mờ 0% | Chỉ còn chữ, gạch chân, tô xanh. Header vẫn có nền mờ tối thiểu 60% và kéo được | |
| [ ] | Tắt click xuyên qua | Cài đặt, tắt "Click xuyên qua panel", kéo panel ở bất kỳ đâu | Có viền nét đứt, kéo được, Notepad vẫn giữ focus | |
| [ ] | Bật lại click xuyên qua | Bật lại | Panel ở nguyên chỗ, viền biến mất, click lại đi xuống cửa sổ phía sau | |
| [ ] | Giữ vị trí sau khi khởi động lại | Kéo panel ra giữa màn hình, Thoát, mở lại | Panel ở đúng chỗ đã kéo | |
| [ ] | Về góc đã chọn | Cài đặt, bấm "Về góc đã chọn" | Panel về góc, cách mép 20 | |
| [ ] | Nội dung dài ra | Kéo panel sát mép dưới, rồi gõ câu rất dài | Panel dời lên, nằm trọn trên màn hình | |
| [ ] | Góc dưới phải, taskbar ở dưới | Chọn góc dưới phải | Cạnh dưới panel cách mép trên taskbar 20, không bị taskbar che | |
| [ ] | Taskbar ở cạnh trên hoặc trái | Đổi vị trí taskbar (Windows 10) | Panel không bị taskbar che | |
| [ ] | Scale 150% | Settings › Display, scale 150% | Panel rộng gấp 1.5 lần (460 thành 690 pixel), chữ rõ nét | |
| [ ] | Kéo sang màn hình khác scale | Có 2 màn hình scale khác nhau, kéo panel sang màn hình kia | Kích thước nhìn thấy giữ nguyên, chữ rõ, panel nằm trọn trong màn hình mới | |
| [ ] | Ứng dụng toàn màn hình | Mở một video toàn màn hình | Ghi lại panel có nổi trên cùng không (không bắt buộc) | |

## 3. Khay hệ thống, copy (spec checker-window)

| | Scenario | Cách làm | Mong đợi | Ghi chú |
|---|---|---|---|---|
| [ ] | Menu khay | Click chuột phải icon Grammar ở khay | Có đủ: Hiện/Ẩn panel, Tạm dừng/Tiếp tục, Copy câu đã sửa, Cài đặt…, Thoát | |
| [ ] | Không có nút taskbar | Nhìn taskbar | Không có nút nào của Grammar (trừ khi cửa sổ Cài đặt đang mở) | |
| [ ] | Ẩn panel | Chọn "Ẩn panel" | Panel biến mất, icon khay vẫn còn. Double-click icon thì panel hiện lại | |
| [ ] | Copy câu sửa | Panel đang báo "Có lỗi", chọn "Copy câu đã sửa", dán vào Notepad | Dán ra câu đã sửa, app nguồn không bị đổi | |
| [ ] | Copy khi không có câu sửa | Panel báo "Không có lỗi ngữ pháp", mở menu khay | Mục "Copy câu đã sửa" bị mờ, clipboard không đổi | |
| [ ] | Thoát | Chọn "Thoát" | Icon khay và panel biến mất, process Grammar không còn trong Task Manager | |

## 4. Cài đặt và model (spec checker-window, grammar-correction)

| | Scenario | Cách làm | Mong đợi | Ghi chú |
|---|---|---|---|---|
| [ ] | Mở Cài đặt | Menu khay › "Cài đặt…" | Cửa sổ Cài đặt hiện lên phía trước, đủ các mục: độ mờ, click xuyên qua, góc, độ rộng, model, dòng "Đang chạy trên: …" | |
| [ ] | Thay đổi áp dụng ngay | Kéo thanh độ mờ, đổi góc, đổi độ rộng | Panel đổi ngay | |
| [ ] | Lưu cài đặt | Độ mờ 30%, góc dưới trái, Thoát, mở lại | Panel ở góc dưới trái, nền 30% | |
| [ ] | Phần cứng | Xem dòng "Đang chạy trên" | Máy có GPU (driver Vulkan): "GPU". Không có: "CPU" | |
| [ ] | Chuyển sang model nhỏ hơn | Đặt cả 7B và 3B vào `Models\`, chọn 3B | Panel báo "Đang nạp model", sau đó kiểm tra bằng 3B. Khởi động lại vẫn là 3B | |
| [ ] | File model đã chọn bị xoá | Thoát, xoá file 3B, mở lại | Dùng 7B (mặc định), không báo lỗi | |
| [ ] | Thiếu thư mục model | Đổi tên thư mục `Models`, mở app | Panel báo lỗi, ghi rõ tên file model cần đặt vào thư mục `Models`; khay và Cài đặt vẫn dùng được | |
| [ ] | Không có mạng | Tắt Wi-Fi, gõ "They was happy." | Vẫn sửa thành "They were happy." | |
| [ ] | Độ trễ | Gõ "The datas shows that sales has increase." rồi dừng | GPU: kết quả trong 1.5 giây. CPU: panel báo "Đang kiểm tra", không treo, Notepad gõ bình thường. Ghi số giây | |

## 5. Vòng đời app

| | Scenario | Cách làm | Mong đợi | Ghi chú |
|---|---|---|---|---|
| [ ] | Mở app lần hai | Ẩn panel, chạy lại `Grammar.exe` | Chỉ một icon khay, một panel, và panel hiện lên | |
| [ ] | Không lưu nội dung | Dùng một lúc, xem `%APPDATA%\Grammar` và `%LOCALAPPDATA%\Grammar` | Chỉ có `settings.json` (và `error.log` nếu có lỗi, không chứa nội dung đã gõ) | |
