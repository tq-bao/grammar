# Spec Delta

## MODIFIED Requirements

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
