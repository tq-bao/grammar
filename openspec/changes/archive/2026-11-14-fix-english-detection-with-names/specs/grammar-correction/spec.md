# Spec Delta

## MODIFIED Requirements

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
