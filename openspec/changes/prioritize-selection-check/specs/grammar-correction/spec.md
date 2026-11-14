# Spec Delta

## MODIFIED Requirements

### Requirement: Chỉ kiểm tra câu tiếng Anh
Hệ thống SHALL chỉ kiểm tra những câu có ít nhất 3 từ và được nhận diện là tiếng Anh. Một câu được coi là tiếng Anh khi bộ nhận diện ngôn ngữ trên máy (đã được báo trước rằng người dùng chủ yếu gõ tiếng Anh và tiếng Việt) cho khả năng là tiếng Anh từ 50% trở lên. Tên riêng tiếng Việt trong câu tiếng Anh MUST NOT làm câu bị coi là không phải tiếng Anh. Câu không đạt điều kiện SHALL bị bỏ qua mà không gọi mô hình. Ngoại lệ: đoạn bôi đen (lấy tự động hoặc qua phím tắt) SHALL được kiểm tra khi có ít nhất 1 từ; đoạn bôi đen dưới 3 từ SHALL bỏ qua bước nhận diện ngôn ngữ, còn đoạn từ 3 từ trở lên vẫn phải được nhận diện là tiếng Anh.

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

#### Scenario: Đoạn bôi đen một từ
- **WHEN** đoạn bôi đen là "recieve"
- **THEN** hệ thống đưa đoạn đó đi kiểm tra

#### Scenario: Câu một từ không bôi đen
- **WHEN** ô chỉ chứa "recieve", không có vùng chọn
- **THEN** hệ thống không kiểm tra

#### Scenario: Đoạn bôi đen tiếng Việt dài
- **WHEN** đoạn bôi đen là "Hôm nay tôi đi học muộn."
- **THEN** hệ thống không kiểm tra và panel ghi rằng câu không phải tiếng Anh

#### Scenario: Phím tắt với một từ
- **WHEN** người dùng bôi đen "recieve" và bấm `⌃⌥G`
- **THEN** hệ thống đưa "recieve" đi kiểm tra

### Requirement: Loại kết quả viết lại câu
Hệ thống SHALL coi kết quả là viết lại câu khi số từ trong câu gốc bị thay bằng một từ khác hẳn vượt 40% số từ, hoặc khi tổng số từ thay đổi vượt 80%. Ngưỡng tổng 80% SHALL không áp dụng cho đoạn bôi đen dưới 3 từ; ngưỡng 40% từ khác hẳn vẫn áp dụng. Từ chỉ được sửa dạng hoặc chính tả (cùng gốc, hoặc gần giống về chữ viết) MUST NOT bị tính là thay bằng từ khác hẳn. Kết quả bị coi là viết lại câu MUST NOT được hiển thị như câu sửa, và panel báo rằng không chắc chắn.

#### Scenario: Mô hình diễn đạt lại câu
- **WHEN** mô hình trả về một câu dùng phần lớn từ ngữ khác với câu gốc
- **THEN** panel không hiển thị câu đó mà báo "không chắc chắn"

#### Scenario: Câu ngắn có nhiều lỗi dạng từ
- **WHEN** câu gốc là "I'm collect more envidences" và mô hình trả về "I'm collecting more evidence"
- **THEN** panel hiển thị câu sửa, gạch chân "collect" và "envidences", và không báo "không chắc chắn"

#### Scenario: Sửa trợ động từ và chính tả
- **WHEN** câu gốc là "She dont has any monies" và mô hình trả về "She doesn't have any money"
- **THEN** panel hiển thị câu sửa và không báo "không chắc chắn"

#### Scenario: Sửa chính tả đoạn bôi đen một từ
- **WHEN** đoạn bôi đen là "recieve" và mô hình trả về "receive"
- **THEN** panel hiển thị câu sửa "receive" và không báo "không chắc chắn"

#### Scenario: Đoạn bôi đen một từ bị thay bằng từ khác hẳn
- **WHEN** đoạn bôi đen là "go" và mô hình trả về "went"
- **THEN** panel không hiển thị câu sửa mà báo "không chắc chắn"
