import AppKit
import GrammarKit
import SwiftUI

@main
struct GrammarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Grammar", systemImage: "textformat.abc") {
            MenuBarContent(model: appDelegate.model)
        }

        Settings {
            SettingsView(settings: appDelegate.model.settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let model = AppModel()

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }
}

struct MenuBarContent: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(model.isPanelVisible ? "Ẩn panel" : "Hiện panel") { model.togglePanel() }
        Button(model.isPaused ? "Tiếp tục theo dõi" : "Tạm dừng") { model.togglePause() }
        Button("Copy câu đã sửa  (⌃⌥C)") { model.copyCorrection() }
            .disabled(!model.canCopyCorrection)
        Divider()
        ModelMenuItems(model: model)
        if !model.isTrusted {
            Button("Cấp quyền Accessibility…") { model.openAccessibilitySettings() }
        }
        Button("Cài đặt…") {
            // App không có Dock icon nên phải tự đưa cửa sổ Cài đặt lên trước.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Text("⌃⌥G: kiểm tra đoạn đang bôi đen")
        Divider()
        Button("Thoát Grammar") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Mục tải model trên menu bar. Ẩn khi model đã sẵn sàng hoặc đang nạp.
struct ModelMenuItems: View {
    let model: AppModel

    var body: some View {
        switch model.modelStatus {
        case let .missing(partial) where partial > 0:
            Button("Tải tiếp model (đã tải \(TwoPaneView.percent(partial, ModelLocator.defaultModelSize))%)…") { model.downloadModel() }
            Divider()
        case .missing:
            Button("Tải model…") { model.downloadModel() }
            Divider()
        case let .downloading(received, total):
            Text("Đang tải model… \(TwoPaneView.percent(received, total))%")
            Button("Huỷ tải") { model.cancelDownload() }
            Divider()
        case .verifying:
            Text("Đang kiểm tra model…")
            Divider()
        case .failed:
            Button("Thử lại tải model") { model.downloadModel() }
            Divider()
        case .loading, .ready, .loadFailed:
            EmptyView()
        }
    }
}
