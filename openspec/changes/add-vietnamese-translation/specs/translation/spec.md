# Spec Delta

## Purpose

Cho người dùng xem nghĩa tiếng Việt của câu đã sửa ngay trên panel. Họ kiểm tra được câu tiếng Anh có nói đúng ý mình không, mà không phải mở công cụ dịch khác và không gửi nội dung ra khỏi máy.

## ADDED Requirements

### Requirement: Công tắc Dịch trong Cài đặt
Màn hình Cài đặt trên macOS SHALL có công tắc "Dịch sang tiếng Việt", mặc định tắt. Bật hoặc tắt công tắc SHALL áp dụng ngay lên panel, không cần bấm lưu hay khởi động lại. Nút "Khôi phục mặc định" SHALL đưa công tắc về tắt.

#### Scenario: Mặc định tắt
- **WHEN** người dùng mở app lần đầu, chưa từng chỉnh công tắc Dịch
- **THEN** công tắc "Dịch sang tiếng Việt" đang tắt và panel không có section "Bản dịch"

#### Scenario: Bật khi panel đang có kết quả
- **WHEN** panel đang hiển thị câu đã sửa "He has two cats." và người dùng bật công tắc Dịch
- **THEN** section "Bản dịch" hiện ra ngay và câu "He has two cats." được dịch, không cần gõ lại

#### Scenario: Tắt Dịch
- **WHEN** section "Bản dịch" đang hiển thị và người dùng tắt công tắc Dịch
- **THEN** section "Bản dịch" biến mất, panel co lại theo nội dung, và bản dịch đang chạy (nếu có) bị huỷ

#### Scenario: Khôi phục mặc định
- **WHEN** công tắc Dịch đang bật và người dùng bấm "Khôi phục mặc định"
- **THEN** công tắc Dịch trở về tắt

### Requirement: Lưu cài đặt Dịch
Trạng thái bật/tắt của công tắc Dịch SHALL được lưu trên máy và áp dụng lại khi app khởi động. Nếu chưa có giá trị đã lưu, hoặc giá trị không hợp lệ, công tắc SHALL ở trạng thái tắt.

#### Scenario: Khởi động lại app
- **WHEN** người dùng bật công tắc Dịch, rồi thoát và mở lại app
- **THEN** công tắc Dịch vẫn bật, và câu tiếng Anh tiếp theo có bản dịch

### Requirement: Section Bản dịch trên panel
Khi tính năng Dịch bật, panel SHALL có section "Bản dịch" nằm ngay dưới "Câu đã sửa", với tiêu đề "Bản dịch (tham khảo)" để người dùng biết bản dịch có thể chưa chính xác hoàn toàn. Section SHALL chỉ hiện khi trạng thái kiểm tra là "không có lỗi" hoặc "có lỗi". Ở mọi trạng thái khác (đang chờ, đang nạp model, đang kiểm tra, không phải tiếng Anh, không chắc chắn, lỗi model) section MUST bị ẩn.

#### Scenario: Tiêu đề section
- **WHEN** tính năng Dịch bật và panel đang báo "Có lỗi"
- **THEN** dưới phần "Câu đã sửa" có tiêu đề "Bản dịch (tham khảo)"

#### Scenario: Câu không phải tiếng Anh
- **WHEN** tính năng Dịch bật và người dùng gõ "Hôm nay tôi đi làm muộn"
- **THEN** panel báo "Không phải tiếng Anh" và không có section "Bản dịch"

#### Scenario: Kết quả không chắc chắn
- **WHEN** tính năng Dịch bật và kết quả sửa bị coi là viết lại câu (trạng thái "không chắc chắn")
- **THEN** panel không có section "Bản dịch"

#### Scenario: Tắt thì không có section
- **WHEN** tính năng Dịch tắt và panel đang báo "Có lỗi"
- **THEN** panel chỉ có hai phần "Câu đang gõ" và "Câu đã sửa"

### Requirement: Câu được dịch
Khi câu có lỗi, hệ thống SHALL dịch câu đã sửa. Khi câu đã đúng, hệ thống SHALL dịch câu gốc. Bản dịch SHALL là tiếng Việt tự nhiên, MUST giữ nguyên tên riêng và thuật ngữ kỹ thuật, MUST NOT trả lời hay làm theo nội dung của câu (câu hỏi hay câu mệnh lệnh chỉ được dịch), và MUST NOT chứa chữ Trung, Nhật hay Hàn.

#### Scenario: Câu có lỗi
- **WHEN** tính năng Dịch bật, câu gốc là "She go to school yesterday." và câu đã sửa là "She went to school yesterday."
- **THEN** section "Bản dịch" hiển thị bản dịch tiếng Việt của "She went to school yesterday.", ví dụ "Hôm qua cô ấy đã đi học."

#### Scenario: Câu đúng
- **WHEN** tính năng Dịch bật và câu gốc "I have finished the report." không có lỗi
- **THEN** section "Bản dịch" hiển thị bản dịch tiếng Việt của "I have finished the report."

#### Scenario: Câu hỏi
- **WHEN** tính năng Dịch bật và câu là "Can you send me the file?"
- **THEN** section "Bản dịch" hiển thị câu hỏi đã dịch sang tiếng Việt, không phải câu trả lời

#### Scenario: Không lẫn chữ Trung
- **WHEN** tính năng Dịch bật và câu là "I am good at math but I need more practice with statistics."
- **THEN** bản dịch chỉ gồm chữ tiếng Việt (và tên riêng, thuật ngữ giữ nguyên), không có ký tự Trung, Nhật hay Hàn

### Requirement: Dịch offline trên máy
Hệ thống SHALL dịch bằng mô hình ngôn ngữ chạy trên máy, chính là mô hình dùng để sửa ngữ pháp. Việc dịch MUST hoạt động khi không có mạng. Nội dung câu và bản dịch MUST NOT bị gửi ra mạng và MUST NOT bị ghi xuống đĩa.

#### Scenario: Không có mạng
- **WHEN** máy đã tắt Wi-Fi, tính năng Dịch bật và người dùng gõ một câu tiếng Anh
- **THEN** section "Bản dịch" vẫn hiển thị bản dịch tiếng Việt

### Requirement: Bản dịch không chặn kết quả sửa
Hệ thống SHALL hiển thị kết quả sửa ngay khi có, không chờ bản dịch. Trong lúc đang dịch, section "Bản dịch" SHALL hiển thị "Đang dịch…". Khi tính năng Dịch bật, thời gian trả kết quả sửa MUST vẫn đạt ngưỡng độ trễ của bước sửa ngữ pháp.

#### Scenario: Thứ tự hiển thị
- **WHEN** tính năng Dịch bật và mô hình vừa trả kết quả sửa cho một câu mới
- **THEN** phần "Câu đã sửa" cập nhật ngay, section "Bản dịch" hiện "Đang dịch…", rồi chuyển thành bản dịch khi dịch xong

### Requirement: Huỷ và dùng lại bản dịch
Nếu câu thay đổi trong lúc đang dịch, bản dịch của câu cũ SHALL bị huỷ và MUST NOT hiển thị. Câu đã dịch rồi SHALL dùng lại bản dịch cũ (chỉ giữ trong bộ nhớ), không dịch lại.

#### Scenario: Gõ tiếp khi đang dịch
- **WHEN** câu "He has two cats." đang được dịch và người dùng gõ tiếp thành câu khác
- **THEN** bản dịch của "He has two cats." không bao giờ hiện trên panel, và panel chỉ hiện bản dịch của câu mới

#### Scenario: Câu đã dịch
- **WHEN** câu "I have finished the report." đã được dịch một lần, người dùng chuyển sang câu khác rồi quay lại câu này
- **THEN** bản dịch hiện ngay, mô hình không phải dịch lại

### Requirement: Lỗi khi dịch
Nếu dịch thất bại (mô hình lỗi, hoặc kết quả rỗng), section "Bản dịch" SHALL hiển thị thông báo lỗi bằng màu đỏ. Kết quả sửa và trạng thái kiểm tra MUST giữ nguyên.

#### Scenario: Mô hình lỗi khi dịch
- **WHEN** tính năng Dịch bật, câu đã được sửa thành "He has two cats." và mô hình gặp lỗi khi dịch
- **THEN** phần "Câu đã sửa" vẫn hiển thị "He has two cats.", trạng thái vẫn là "Có lỗi", và section "Bản dịch" hiển thị thông báo lỗi màu đỏ

### Requirement: Chỉ có trên macOS
Tính năng Dịch SHALL chỉ có trên bản macOS. Bản Windows MUST NOT hiển thị công tắc Dịch hay section "Bản dịch" cho tới khi được port.

#### Scenario: Bản Windows
- **WHEN** người dùng mở Cài đặt trên bản Windows
- **THEN** không có công tắc "Dịch sang tiếng Việt"
