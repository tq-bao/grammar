## MODIFIED Requirements

### Requirement: Panel hai phần
Hệ thống SHALL hiển thị một panel gồm hai phần. Phần trên hiển thị câu gốc đang được kiểm tra. Phần dưới hiển thị câu đã sửa. Trên macOS, khi tính năng Dịch bật, panel SHALL có thêm section "Bản dịch" nằm dưới phần câu đã sửa, theo capability `translation`.

#### Scenario: Có lỗi ngữ pháp
- **WHEN** câu gốc là "She go to school yesterday." và câu sửa là "She went to school yesterday."
- **THEN** phần trên hiển thị "She go to school yesterday." và phần dưới hiển thị "She went to school yesterday."

#### Scenario: Có thêm section Bản dịch
- **WHEN** trên macOS, tính năng Dịch bật và câu sửa là "She went to school yesterday."
- **THEN** dưới phần câu đã sửa có section "Bản dịch" chứa bản dịch tiếng Việt của câu đó
