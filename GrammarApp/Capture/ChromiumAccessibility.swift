import AppKit
import ApplicationServices

/// Bật cây accessibility cho app nền Chromium (Chrome, Edge, Slack, Teams, app Electron, app WebView2).
///
/// Mặc định các app này không dựng cây accessibility cho tới khi có trình đọc màn hình,
/// nên ô nhập liệu không trả về nội dung. Chỉ set cờ cho đúng nhóm app này, mỗi pid một lần.
@MainActor
enum ChromiumAccessibility {
    private static let browserBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
        "com.microsoft.edgemac", "com.brave.Browser", "com.vivaldi.Vivaldi", "company.thebrowser.Browser",
        "org.chromium.Chromium", "com.operasoftware.Opera",
    ]

    /// App Electron biết trước bundle id (phòng khi không tìm thấy Electron Framework).
    private static let electronBundleIDs: Set<String> = [
        "com.tinyspeck.slackmacgap", "com.microsoft.teams",
        "com.hnc.Discord", "notion.id", "com.microsoft.VSCode",
    ]

    /// App dùng Edge WebView2 biết trước bundle id (phòng khi không tìm thấy MSWebView2.framework).
    private static let webView2BundleIDs: Set<String> = ["com.microsoft.teams2"]

    private static var enabledPIDs: Set<pid_t> = []
    /// Kết quả `kind(of:)` theo đường dẫn bundle, để không phải kiểm tra file mỗi lần poll.
    private static var kindCache: [String: Kind?] = [:]

    enum Kind {
        case browser
        case electron
        /// Nội dung web chạy trong tiến trình Edge WebView2 riêng (helper nằm trong bundle của app),
        /// ví dụ Teams bản mới. Phải bật `AXEnhancedUserInterface` ở tiến trình helper đó:
        /// bật ở tiến trình chính, hay bật `AXManualAccessibility` (cờ của Electron), đều không có tác dụng.
        case webView2
    }

    static func kind(of app: NSRunningApplication) -> Kind? {
        guard let id = app.bundleIdentifier else { return nil }
        let key = app.bundleURL?.path ?? id
        if let cached = kindCache[key] { return cached }

        let frameworks = app.bundleURL?.appendingPathComponent("Contents/Frameworks")
        func hasFramework(_ name: String) -> Bool {
            guard let frameworks else { return false }
            return FileManager.default.fileExists(atPath: frameworks.appendingPathComponent(name).path)
        }

        let kind: Kind? =
            if browserBundleIDs.contains(id) { .browser }
            else if webView2BundleIDs.contains(id) || hasFramework("MSWebView2.framework") { .webView2 }
            else if electronBundleIDs.contains(id) || hasFramework("Electron Framework.framework") { .electron }
            else { nil }
        kindCache[key] = kind
        return kind
    }

    /// Bật cây accessibility cho `app`. Gọi lại nhiều lần được: pid nào đã bật thì bỏ qua,
    /// còn helper WebView2 mới khởi động sau lần gọi trước sẽ được bật ở lần này.
    static func enableIfNeeded(for app: NSRunningApplication) {
        guard let kind = kind(of: app) else { return }
        switch kind {
        case .browser:
            enable(app.processIdentifier, attribute: "AXEnhancedUserInterface")
        case .electron:
            enable(app.processIdentifier, attribute: "AXManualAccessibility")
        case .webView2:
            // Không set ở tiến trình chính (app AppKit): ở đó cờ này vô dụng mà còn làm chậm animation cửa sổ.
            for helper in helpers(of: app) {
                enable(helper.processIdentifier, attribute: "AXEnhancedUserInterface")
            }
        }
    }

    /// Tiến trình đang chạy mà bundle nằm bên trong bundle của `app` (ví dụ
    /// `Microsoft Teams.app/Contents/Helpers/Microsoft Teams WebView.app`).
    private static func helpers(of app: NSRunningApplication) -> [NSRunningApplication] {
        guard let root = app.bundleURL?.standardizedFileURL.path else { return [] }
        return NSWorkspace.shared.runningApplications.filter { other in
            other.processIdentifier != app.processIdentifier
                && (other.bundleURL?.standardizedFileURL.path.hasPrefix(root + "/") ?? false)
        }
    }

    private static func enable(_ pid: pid_t, attribute: String) {
        guard !enabledPIDs.contains(pid) else { return }
        let element = AXUIElementCreateApplication(pid)
        // Chromium thường trả lỗi cho lệnh set này dù cờ vẫn có tác dụng, nên không kiểm tra kết quả.
        AXUIElementSetAttributeValue(element, attribute as CFString, kCFBooleanTrue)
        enabledPIDs.insert(pid)
    }

    static func forget(_ pid: pid_t) {
        enabledPIDs.remove(pid)
    }
}
