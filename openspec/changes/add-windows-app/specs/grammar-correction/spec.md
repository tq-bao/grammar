# Spec Delta

## MODIFIED Requirements

### Requirement: Sửa ngữ pháp offline
Hệ thống SHALL sửa ngữ pháp bằng mô hình ngôn ngữ chạy trên máy và MUST hoạt động khi không có mạng. Trên macOS, mô hình được đóng gói kèm app. Trên Windows, mô hình là file đặt trong thư mục `Models` cạnh file chạy của app.

#### Scenario: Không có mạng
- **WHEN** máy không có kết nối mạng và người dùng gõ "They was happy."
- **THEN** hệ thống vẫn trả về "They were happy."

#### Scenario: Model chưa sẵn sàng
- **WHEN** không tìm thấy file model hoặc model không nạp được
- **THEN** panel hiển thị thông báo lỗi rõ ràng, còn app vẫn chạy và không crash

#### Scenario: Thiếu thư mục model trên Windows
- **WHEN** trên Windows, người dùng giải nén app nhưng chưa đặt file model vào thư mục `Models`
- **THEN** panel báo lỗi model và ghi rõ tên file model cần đặt vào thư mục `Models`, còn icon khay và Cài đặt vẫn dùng được

### Requirement: Độ trễ chấp nhận được
Với câu dài tối đa 40 từ, hệ thống SHALL trả kết quả trong vòng 1.5 giây (tính từ lúc bắt đầu kiểm tra), sau khi model đã được nạp, trên: máy Apple Silicon có từ 16 GB RAM trở lên, hoặc máy Windows chạy model trên GPU có từ 6 GB bộ nhớ đồ hoạ trở lên. Trên Windows chạy bằng CPU hoặc GPU yếu hơn thì không có ngưỡng cứng, nhưng giao diện MUST NOT bị treo trong lúc chờ.

#### Scenario: Câu bình thường
- **WHEN** người dùng dừng gõ sau câu "The datas shows that sales has increase."
- **THEN** kết quả hiển thị trong vòng 1.5 giây

#### Scenario: Windows chạy bằng CPU
- **WHEN** trên Windows, model chạy bằng CPU và việc kiểm tra một câu mất vài giây
- **THEN** panel hiển thị "Đang kiểm tra" cho tới khi có kết quả, panel và menu khay vẫn phản hồi bình thường, và app người dùng đang gõ không bị chậm

## ADDED Requirements

### Requirement: Tự chọn phần cứng chạy mô hình trên Windows
Trên Windows, hệ thống SHALL chạy mô hình trên GPU khi máy có GPU dùng được. Nếu không có GPU, hoặc nạp mô hình lên GPU bị lỗi, hệ thống SHALL tự chuyển sang chạy bằng CPU mà không crash và không cần người dùng thao tác. Phần cứng đang dùng SHALL được hiển thị trong Cài đặt.

#### Scenario: Máy có GPU
- **WHEN** trên Windows, máy có GPU dùng được và đủ bộ nhớ cho model
- **THEN** model chạy trên GPU và Cài đặt ghi "Đang chạy trên: GPU"

#### Scenario: Máy không có GPU dùng được
- **WHEN** trên Windows, máy chỉ có GPU tích hợp không dùng được, hoặc nạp model lên GPU thất bại
- **THEN** model được nạp lại để chạy bằng CPU, việc kiểm tra vẫn hoạt động, và Cài đặt ghi "Đang chạy trên: CPU"

### Requirement: Chọn model trên Windows
Trên Windows, khi thư mục `Models` có nhiều file model, Cài đặt SHALL cho người dùng chọn model nào được dùng. Mặc định là model mặc định của app (giống macOS). Lựa chọn SHALL được lưu lại, và áp dụng bằng cách nạp lại model mà không cần khởi động lại app. Lựa chọn trỏ tới file không còn tồn tại SHALL được thay bằng model mặc định.

#### Scenario: Chuyển sang model nhỏ hơn
- **WHEN** thư mục `Models` có cả model 7B và 3B, và người dùng chọn model 3B trong Cài đặt
- **THEN** panel báo đang nạp model, sau đó các lần kiểm tra dùng model 3B, và lựa chọn vẫn còn sau khi khởi động lại app

#### Scenario: File model đã chọn bị xoá
- **WHEN** model đã chọn bị xoá khỏi thư mục `Models` rồi app được khởi động lại
- **THEN** app dùng model mặc định nếu có, hoặc báo lỗi model rõ ràng nếu không có

### Requirement: Kết quả giống nhau giữa macOS và Windows
Với cùng một câu gốc và cùng kết quả trả về của mô hình, hai nền tảng SHALL cho cùng một quyết định ở mọi bước: lọc câu (tiếng Anh, độ dài), đối chiếu viết hoa và dấu câu cuối câu, phát hiện viết lại câu, các từ bị gạch chân và các từ được làm nổi bật. Trên golden set dùng chung, bản Windows SHALL đạt cùng ngưỡng chất lượng với bản macOS: giữ nguyên câu đúng từ 95% trở lên và khớp đáp án từ 80% trở lên.

#### Scenario: Scenario nhận diện ngôn ngữ trên Windows
- **WHEN** trên Windows, câu lấy được lần lượt là "Hi, my name is Bao", "ok I will ping Tuan", "Hôm nay tôi đi học muộn." và "anh check giup em cai PR nay nhe"
- **THEN** hai câu đầu được đưa đi kiểm tra, còn hai câu sau bị báo không phải tiếng Anh, giống macOS

#### Scenario: Golden set trên bản Windows
- **WHEN** chạy công cụ benchmark của bản Windows trên golden set dùng chung với model mặc định
- **THEN** tỷ lệ giữ nguyên câu đúng từ 95% trở lên và tỷ lệ khớp đáp án từ 80% trở lên
