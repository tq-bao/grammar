# Spec Delta

## Purpose

Kiểm tra và sửa ngữ pháp các câu tiếng Anh hoàn toàn offline bằng mô hình ngôn ngữ chạy trên máy. Chỉ sửa lỗi ngữ pháp, giữ nguyên ý nghĩa, giọng văn và cách dùng từ của người viết.

## ADDED Requirements

### Requirement: Chỉ kiểm tra câu tiếng Anh
Hệ thống SHALL chỉ kiểm tra những câu được nhận diện là tiếng Anh với độ tin cậy cao và có ít nhất 3 từ. Câu không đạt điều kiện SHALL bị bỏ qua mà không gọi mô hình.

#### Scenario: Câu tiếng Anh
- **WHEN** câu lấy được là "She go to school yesterday."
- **THEN** hệ thống đưa câu đó đi kiểm tra ngữ pháp

#### Scenario: Câu tiếng Việt
- **WHEN** câu lấy được là "Hôm nay tôi đi học muộn."
- **THEN** hệ thống không kiểm tra và panel ghi rằng câu không phải tiếng Anh

#### Scenario: Câu quá ngắn
- **WHEN** câu lấy được là "ok thanks"
- **THEN** hệ thống không kiểm tra

### Requirement: Sửa ngữ pháp offline
Hệ thống SHALL sửa ngữ pháp bằng mô hình ngôn ngữ chạy trên máy, đóng gói kèm app, và MUST hoạt động khi không có mạng.

#### Scenario: Không có mạng
- **WHEN** máy không có kết nối mạng và người dùng gõ "They was happy."
- **THEN** hệ thống vẫn trả về "They were happy."

#### Scenario: Model chưa sẵn sàng
- **WHEN** không tìm thấy file model hoặc model không nạp được
- **THEN** panel hiển thị thông báo lỗi rõ ràng, còn app vẫn chạy và không crash

### Requirement: Chỉ sửa ngữ pháp, giữ nguyên ngữ cảnh
Kết quả sửa SHALL chỉ thay đổi những gì cần để câu đúng ngữ pháp, chính tả và dấu câu. Kết quả MUST giữ nguyên ý nghĩa, giọng văn, cách dùng từ, tên riêng và thuật ngữ của câu gốc.

#### Scenario: Câu có lỗi chia động từ
- **WHEN** câu gốc là "He have two cats and they is cute."
- **THEN** kết quả là "He has two cats and they are cute."

#### Scenario: Giữ giọng văn thân mật
- **WHEN** câu gốc là "gonna send u the file tmr, it have the numbers"
- **THEN** kết quả chỉ sửa "it have" thành "it has", vẫn giữ các từ "gonna", "u", "tmr"

### Requirement: Câu đúng được giữ nguyên
Nếu câu gốc đã đúng ngữ pháp, hệ thống SHALL trả về đúng câu gốc và báo rằng câu không có lỗi.

#### Scenario: Câu đúng
- **WHEN** câu gốc là "I have finished the report."
- **THEN** kết quả giống hệt câu gốc và panel báo không có lỗi

### Requirement: Loại kết quả viết lại câu
Nếu kết quả thay đổi quá nhiều so với câu gốc (mặc định trên 40% số từ), hệ thống SHALL coi đó là viết lại câu, MUST NOT hiển thị nó như câu sửa, và báo rằng không chắc chắn.

#### Scenario: Mô hình diễn đạt lại câu
- **WHEN** mô hình trả về một câu dùng phần lớn từ ngữ khác với câu gốc
- **THEN** panel không hiển thị câu đó mà báo "không chắc chắn"

### Requirement: Kiểm tra khi người dùng dừng gõ
Hệ thống SHALL chờ người dùng dừng gõ khoảng 700 ms rồi mới kiểm tra. Nếu câu thay đổi trong lúc đang kiểm tra, kết quả cũ SHALL bị huỷ. Câu đã kiểm tra rồi SHALL dùng lại kết quả cũ.

#### Scenario: Đang gõ liên tục
- **WHEN** người dùng gõ liên tục, các phím cách nhau dưới 700 ms
- **THEN** hệ thống chưa gọi mô hình

#### Scenario: Câu thay đổi khi đang kiểm tra
- **WHEN** người dùng gõ thêm trong lúc câu trước đang được kiểm tra
- **THEN** kết quả của câu trước không được hiển thị, chỉ hiển thị kết quả của câu mới nhất

#### Scenario: Câu lặp lại
- **WHEN** một câu đã kiểm tra trước đó xuất hiện lại y hệt
- **THEN** hệ thống hiển thị ngay kết quả cũ mà không gọi lại mô hình

### Requirement: Độ trễ chấp nhận được
Với câu dài tối đa 40 từ, hệ thống SHALL trả kết quả trong vòng 1.5 giây (tính từ lúc bắt đầu kiểm tra) trên máy Apple Silicon có từ 16 GB RAM trở lên, sau khi model đã được nạp.

#### Scenario: Câu bình thường
- **WHEN** người dùng dừng gõ sau câu "The datas shows that sales has increase."
- **THEN** kết quả hiển thị trong vòng 1.5 giây
