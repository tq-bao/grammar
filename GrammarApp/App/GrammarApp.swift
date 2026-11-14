import AppKit
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
