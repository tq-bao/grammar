import GrammarKit
import SwiftUI

extension PanelCorner {
    var displayName: String {
        switch self {
        case .topRight: "Trên phải"
        case .topLeft: "Trên trái"
        case .bottomRight: "Dưới phải"
        case .bottomLeft: "Dưới trái"
        }
    }
}

/// Màn hình Cài đặt: độ mờ nền, góc màn hình, độ rộng panel. Thay đổi áp dụng ngay.
struct SettingsView: View {
    @Bindable var settings: PanelSettings

    var body: some View {
        Form {
            Section("Panel") {
                LabeledContent("Độ mờ nền") {
                    HStack {
                        Slider(value: $settings.backgroundOpacity, in: PanelSettings.opacityRange)
                        Text("\(Int((settings.backgroundOpacity * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                Toggle(isOn: $settings.clickThrough) {
                    Text("Click xuyên qua panel")
                    Text(settings.clickThrough
                         ? "Click và cuộn trên panel đi xuống app phía sau. Tắt để kéo panel đi chỗ khác."
                         : "Đang tắt: kéo panel tới vị trí bạn muốn, rồi bật lại để click xuyên qua.")
                }

                Picker("Góc màn hình", selection: $settings.corner) {
                    ForEach(PanelCorner.allCases, id: \.self) { corner in
                        Text(corner.displayName).tag(corner)
                    }
                }

                if settings.customTopLeft != nil {
                    LabeledContent("Vị trí") {
                        HStack {
                            Text("Đang dùng vị trí bạn đã kéo")
                                .foregroundStyle(.secondary)
                            Button("Về góc đã chọn") { settings.resetPosition() }
                        }
                    }
                }

                LabeledContent("Độ rộng") {
                    HStack {
                        Slider(value: $settings.width, in: PanelSettings.widthRange, step: 10)
                        Text("\(Int(settings.width)) pt")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }

            Section {
                Text("Panel chỉ để xem. Dùng menu bar để ẩn/hiện panel, và ⌃⌥C để copy câu đã sửa.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Khôi phục mặc định") { settings.resetToDefaults() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
