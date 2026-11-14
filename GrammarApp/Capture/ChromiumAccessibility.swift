import AppKit
import ApplicationServices

/// Bật cây accessibility cho app nền Chromium (Chrome, Edge, Slack, Teams, app Electron).
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

    /// App Electron/WebView biết trước bundle id (phòng khi không tìm thấy Electron Framework).
    private static let electronBundleIDs: Set<String> = [
        "com.tinyspeck.slackmacgap", "com.microsoft.teams2", "com.microsoft.teams",
        "com.hnc.Discord", "notion.id", "com.microsoft.VSCode",
    ]

    private static var enabledPIDs: Set<pid_t> = []

    enum Kind { case browser, electron }

    static func kind(of app: NSRunningApplication) -> Kind? {
        guard let id = app.bundleIdentifier else { return nil }
        if browserBundleIDs.contains(id) { return .browser }
        if electronBundleIDs.contains(id) { return .electron }
        if let url = app.bundleURL,
           FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path) {
            return .electron
        }
        return nil
    }

    static func enableIfNeeded(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard !enabledPIDs.contains(pid), let kind = kind(of: app) else { return }
        let element = AXUIElementCreateApplication(pid)
        switch kind {
        case .electron:
            AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        case .browser:
            AXUIElementSetAttributeValue(element, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
        enabledPIDs.insert(pid)
    }

    static func forget(_ pid: pid_t) {
        enabledPIDs.remove(pid)
    }
}
