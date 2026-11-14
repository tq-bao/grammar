# grammar-correction Specification

## Purpose
Kiểm tra và sửa ngữ pháp các câu tiếng Anh hoàn toàn offline bằng mô hình ngôn ngữ chạy trên máy. Chỉ sửa lỗi ngữ pháp, giữ nguyên ý nghĩa, giọng văn và cách dùng từ của người viết.

## Requirements

### Requirement: Chỉ kiểm tra câu tiếng Anh
Hệ thống SHALL chỉ kiểm tra những câu có ít nhất 3 từ và được nhận diện là tiếng Anh. Một câu được coi là tiếng Anh khi bộ nhận diện ngôn ngữ trên máy (đã được báo trước rằng người dùng chủ yếu gõ tiếng Anh và tiếng Việt) cho khả năng là tiếng Anh từ 50% trở lên. Tên riêng tiếng Việt trong câu tiếng Anh MUST NOT làm câu bị coi là không phải tiếng Anh. Câu không đạt điều kiện SHALL bị bỏ qua mà không gọi mô hình.

#### Scenario: Câu tiếng Anh
- **WHEN** câu lấy được là "She go to school yesterday."
- **THEN** hệ thống đưa câu đó đi kiểm tra ngữ pháp

#### Scenario: Câu tiếng Việt
- **WHEN** câu lấy được là "Hôm nay tôi đi học muộn."
- **THEN** hệ thống không kiểm tra và panel ghi rằng câu không phải tiếng Anh

#### Scenario: Câu quá ngắn
- **WHEN** câu lấy được là "ok thanks"
- **THEN** hệ thống không kiểm tra

#### Scenario: Câu tiếng Anh có tên riêng tiếng Việt
- **WHEN** câu lấy được là "Hi, my name is Bao" hoặc "ok I will ping Tuan"
- **THEN** hệ thống đưa câu đó đi kiểm tra ngữ pháp

#### Scenario: Tiếng Việt không dấu
- **WHEN** câu lấy được là "anh check giup em cai PR nay nhe"
- **THEN** hệ thống không kiểm tra và panel ghi rằng câu không phải tiếng Anh

### Requirement: Sửa ngữ pháp offline
Hệ thống SHALL sửa ngữ pháp bằng mô hình ngôn ngữ chạy trên máy, đóng gói kèm app, và MUST hoạt động khi không có mạng.

#### Scenario: Không có mạng
- **WHEN** máy không có kết nối mạng và người dùng gõ "They was happy."
- **THEN** hệ thống vẫn trả về "They were happy."

#### Scenario: Model chưa sẵn sàng
- **WHEN** không tìm thấy file model hoặc model không nạp được
- **THEN** panel hiển thị thông báo lỗi rõ ràng, còn app vẫn chạy và không crash

### Requirement: Chỉ sửa ngữ pháp, giữ nguyên ngữ cảnh
Kết quả sửa SHALL chỉ thay đổi những gì cần để câu đúng ngữ pháp, chính tả và dấu câu ở giữa câu. Kết quả MUST giữ nguyên ý nghĩa, giọng văn, cách dùng từ, tên riêng và thuật ngữ của câu gốc. Kết quả MUST giữ nguyên cách viết hoa/viết thường của các từ không bị sửa, và MUST giữ nguyên dấu câu ở cuối câu gốc (`. , ; : ! ? …`, hoặc không có dấu nào).

#### Scenario: Câu có lỗi chia động từ
- **WHEN** câu gốc là "He have two cats and they is cute."
- **THEN** kết quả là "He has two cats and they are cute."

#### Scenario: Giữ giọng văn thân mật
- **WHEN** câu gốc là "gonna send u the file tmr, it have the numbers"
- **THEN** kết quả chỉ sửa "it have" thành "it has", vẫn giữ các từ "gonna", "u", "tmr"

#### Scenario: Giữ cách viết hoa của người dùng
- **WHEN** câu gốc là "yesterday i go to the office"
- **THEN** kết quả là "yesterday i went to the office": chỉ sửa "go", không viết hoa "yesterday" hay "i", và không thêm dấu chấm cuối câu

#### Scenario: Giữ dấu câu cuối câu của người dùng
- **WHEN** câu gốc là "She go to school yesterday," và mô hình trả về "She went to school yesterday."
- **THEN** kết quả hiển thị là "She went to school yesterday,", và chỉ có từ "go" bị gạch chân

### Requirement: Câu đúng được giữ nguyên
Nếu câu gốc đã đúng ngữ pháp, hệ thống SHALL trả về đúng câu gốc và báo rằng câu không có lỗi. Câu chỉ khác kết quả của mô hình ở viết hoa/viết thường hoặc dấu câu cuối câu SHALL được coi là câu đúng.

#### Scenario: Câu đúng
- **WHEN** câu gốc là "I have finished the report."
- **THEN** kết quả giống hệt câu gốc và panel báo không có lỗi

#### Scenario: Chỉ khác viết hoa và dấu cuối câu
- **WHEN** câu gốc là "thanks, will check it tonight" và mô hình trả về "Thanks, will check it tonight."
- **THEN** panel báo không có lỗi ngữ pháp và không có gạch chân nào

### Requirement: Loại kết quả viết lại câu
Hệ thống SHALL coi kết quả là viết lại câu khi số từ trong câu gốc bị thay bằng một từ khác hẳn vượt 40% số từ, hoặc khi tổng số từ thay đổi vượt 80%. Từ chỉ được sửa dạng hoặc chính tả (cùng gốc, hoặc gần giống về chữ viết) MUST NOT bị tính là thay bằng từ khác hẳn. Kết quả bị coi là viết lại câu MUST NOT được hiển thị như câu sửa, và panel báo rằng không chắc chắn.

#### Scenario: Mô hình diễn đạt lại câu
- **WHEN** mô hình trả về một câu dùng phần lớn từ ngữ khác với câu gốc
- **THEN** panel không hiển thị câu đó mà báo "không chắc chắn"

#### Scenario: Câu ngắn có nhiều lỗi dạng từ
- **WHEN** câu gốc là "I'm collect more envidences" và mô hình trả về "I'm collecting more evidence"
- **THEN** panel hiển thị câu sửa, gạch chân "collect" và "envidences", và không báo "không chắc chắn"

#### Scenario: Sửa trợ động từ và chính tả
- **WHEN** câu gốc là "She dont has any monies" và mô hình trả về "She doesn't have any money"
- **THEN** panel hiển thị câu sửa và không báo "không chắc chắn"

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
