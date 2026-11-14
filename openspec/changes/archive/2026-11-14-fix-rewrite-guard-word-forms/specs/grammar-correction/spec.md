# Spec Delta

## MODIFIED Requirements

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
