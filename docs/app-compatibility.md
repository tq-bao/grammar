# Tương thích theo từng app

Kết quả test tay (task 5.3, 7.2 trong `openspec/changes/add-offline-grammar-checker/tasks.md`).
Cột "Đọc tự động": panel cập nhật khi gõ mà không cần làm gì thêm. Cột "⌃⌥G": bôi đen rồi bấm phím tắt.

| App | Ô thử | Đọc tự động | ⌃⌥G | Ghi chú |
|---|---|---|---|---|
| TextEdit | văn bản | chưa test | chưa test | |
| Notes | ghi chú | chưa test | chưa test | |
| Mail | soạn thư | chưa test | chưa test | |
| Safari | ô text trên web | chưa test | chưa test | |
| Chrome | Gmail soạn thư | chưa test | chưa test | Bật `AXEnhancedUserInterface` |
| Slack | ô nhắn tin | chưa test | chưa test | Bật `AXManualAccessibility` |
| Teams (bản mới, `com.microsoft.teams2`) | ô nhắn tin | được (2026-11-14, Teams 26289) | chưa test | Xem ghi chú Teams bên dưới |
| Safari | ô mật khẩu | phải **không** đọc | – | |

## Ghi chú: Teams bản mới (Edge WebView2)

Teams bản mới không còn là Electron. Nội dung chat chạy trong tiến trình Edge WebView2 riêng: `Microsoft Teams.app/Contents/Helpers/Microsoft Teams WebView.app` (bundle id `com.microsoft.teams2.helper`). Đo trên Teams 26289:

| Cờ được bật | Số phần tử AX trong cửa sổ | Có ô soạn tin |
|---|---|---|
| Không bật gì, hoặc `AXManualAccessibility` ở tiến trình chính (cách cũ) | 11–12 | không |
| `AXManualAccessibility` ở tiến trình WebView | 12 | không |
| `AXEnhancedUserInterface` ở tiến trình WebView | ~370 | có (`AXTextArea` "Type a message", hỗ trợ text marker) |

Vì vậy `ChromiumAccessibility` nhận diện app WebView2 (bundle có `MSWebView2.framework`) và bật `AXEnhancedUserInterface` cho mọi tiến trình helper nằm trong bundle của app. Teams có thể khởi động tiến trình WebView sau khi cửa sổ đã hiện, nên lúc chưa thấy ô focus, `AXTextCapture` thử bật lại mỗi lần poll.

