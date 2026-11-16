import AppKit
import GrammarKit
import SwiftUI

/// Nội dung panel: phần trên là câu gốc (gạch chân đỏ cụm sai),
/// phần dưới là câu đã sửa (tô xanh phần sửa). Khi bật Dịch, có thêm section "Bản dịch"
/// ở dưới cùng. Chỉ để xem, nền trong suốt theo cài đặt.
struct TwoPaneView: View {
    let model: AppModel

    private var coordinator: CheckCoordinator { model.coordinator }
    private var settings: PanelSettings { model.settings }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(width: settings.width)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(settings.backgroundOpacity)))
        // Đang tắt click xuyên qua: viền báo panel đang kéo được.
        .overlay {
            if !settings.clickThrough {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Dải header luôn nhận chuột: kéo để dời panel. Nền mờ tối thiểu 60% để luôn thấy được.
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
            Text("Grammar")
                .font(.system(size: 11, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: PanelLayout.headerHeight)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(max(settings.backgroundOpacity, 0.6))))
        .help("Kéo để di chuyển panel")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.isTrusted {
                PermissionView()
            }
            if coordinator.state.isWaitingForModel, coordinator.state != .loadingModel {
                ModelDownloadView(state: coordinator.state)
            }

            HStack {
                Text("Câu đang gõ").font(.headline)
                Spacer()
                StatusBadge(state: coordinator.state, isPaused: model.isPaused)
            }
            Text(originalContent)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("Câu đã sửa").font(.headline)
            Text(correctedContent)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if let translationContent {
                Divider()

                Text("Bản dịch (tham khảo)").font(.headline)
                Text(translationContent)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
        // Viền mờ màu nền giúp chữ vẫn đọc được khi nền gần như trong suốt.
        .compositingGroup()
        .shadow(color: Color(nsColor: .windowBackgroundColor).opacity(0.9), radius: 1.5)
    }

    static func percent(_ received: Int64, _ total: Int64) -> Int {
        guard total > 0 else { return 0 }
        return Int(min(100, max(0, Double(received) / Double(total) * 100)))
    }

    private func placeholder(_ text: String) -> AttributedString {
        var s = AttributedString(text)
        s.swiftUI.foregroundColor = .secondary
        return s
    }

    private var originalContent: AttributedString {
        switch coordinator.state {
        case let .corrected(diff):
            return DiffHighlighter.originalText(diff)
        default:
            return coordinator.sentence.isEmpty
                ? placeholder("Gõ một câu tiếng Anh ở bất kỳ app nào, hoặc bôi đen rồi bấm ⌃⌥G.")
                : AttributedString(coordinator.sentence)
        }
    }

    /// Nội dung section "Bản dịch". `nil` = ẩn section (Dịch đang tắt, hoặc chưa có gì để dịch).
    private var translationContent: AttributedString? {
        guard settings.translationEnabled else { return nil }
        switch coordinator.translation {
        case .hidden:
            return nil
        case .translating:
            return placeholder("Đang dịch…")
        case let .done(text):
            return AttributedString(text)
        case let .failed(message):
            var s = AttributedString(message)
            s.swiftUI.foregroundColor = .red
            return s
        }
    }

    private var correctedContent: AttributedString {
        switch coordinator.state {
        case let .corrected(diff):
            return DiffHighlighter.correctedText(diff)
        case let .ok(sentence):
            return AttributedString(sentence)
        case .checking:
            return placeholder("Đang kiểm tra…")
        case .notEnglish:
            return placeholder("Câu này không phải tiếng Anh nên không kiểm tra.")
        case .uncertain:
            return placeholder("Không chắc chắn: model muốn viết lại cả câu nên kết quả bị bỏ qua.")
        case let .modelError(message):
            var s = AttributedString(message)
            s.swiftUI.foregroundColor = .red
            return s
        case .loadingModel:
            return placeholder("Đang nạp model…")
        case .modelMissing:
            return placeholder("Cần tải model trước khi kiểm tra.")
        case let .downloadingModel(received, total):
            return placeholder("Đang tải model… \(Self.percent(received, total))%")
        case .verifyingModel:
            return placeholder("Đang kiểm tra model…")
        case .idle:
            return placeholder("—")
        }
    }
}

private struct StatusBadge: View {
    let state: CheckState
    let isPaused: Bool

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var text: String {
        if isPaused { return "Đã tạm dừng" }
        switch state {
        case .idle: return "Đang chờ"
        case .loadingModel: return "Đang nạp model"
        case .modelMissing: return "Cần tải model"
        case let .downloadingModel(received, total): return "Đang tải model \(TwoPaneView.percent(received, total))%"
        case .verifyingModel: return "Đang kiểm tra model"
        case .checking: return "Đang kiểm tra"
        case .ok: return "Không có lỗi ngữ pháp"
        case let .corrected(diff):
            let count = DiffHighlighter.highlights(for: diff).underlines.count + diff.missingPositions.count
            return "Có lỗi (\(max(count, 1)))"
        case .notEnglish: return "Không phải tiếng Anh"
        case .uncertain: return "Không chắc chắn"
        case .modelError: return "Lỗi model"
        }
    }

    private var icon: String {
        if isPaused { return "pause.circle" }
        switch state {
        case .idle: return "keyboard"
        case .loadingModel, .checking, .verifyingModel: return "hourglass"
        case .modelMissing, .downloadingModel: return "arrow.down.circle"
        case .ok: return "checkmark.circle"
        case .corrected: return "exclamationmark.circle"
        case .notEnglish: return "globe"
        case .uncertain: return "questionmark.circle"
        case .modelError: return "xmark.octagon"
        }
    }

    private var color: Color {
        if isPaused { return .secondary }
        switch state {
        case .ok: return .green
        case .corrected, .modelError: return .red
        case .uncertain, .modelMissing: return .orange
        default: return .secondary
        }
    }
}

/// Hướng dẫn tải model và tiến độ tải. Panel không nhận chuột nên nút tải nằm ở menu bar.
private struct ModelDownloadView: View {
    let state: CheckState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch state {
            case let .downloadingModel(received, total):
                Label("Đang tải model", systemImage: "arrow.down.circle")
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    ProgressView(value: Double(received), total: Double(max(total, 1)))
                    Text("\(TwoPaneView.percent(received, total))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 34, alignment: .trailing)
                }
            case .verifyingModel:
                Label("Đang kiểm tra model…", systemImage: "checkmark.shield")
                    .font(.subheadline.bold())
                ProgressView()
                    .progressViewStyle(.linear)
            default:
                Label("Cần tải model", systemImage: "arrow.down.circle")
                    .font(.subheadline.bold())
                Text("Chọn biểu tượng Grammar trên menu bar › \"Tải model…\". Chỉ tải một lần, sau đó app chạy hoàn toàn offline.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }
}
