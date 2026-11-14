import SwiftUI

/// Hướng dẫn cấp quyền Accessibility. Panel không nhận chuột nên việc mở System Settings
/// nằm ở menu bar. App tự kiểm tra lại mỗi giây và bắt đầu theo dõi khi có quyền.
struct PermissionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Cần quyền Accessibility", systemImage: "lock.shield")
                .font(.subheadline.bold())
            Text("Để đọc câu bạn đang gõ, chọn biểu tượng Grammar trên menu bar › \"Cấp quyền Accessibility…\" rồi bật Grammar trong danh sách.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}
