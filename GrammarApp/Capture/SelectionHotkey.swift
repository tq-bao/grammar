import AppKit
import Carbon.HIToolbox

/// Lấy đoạn đang bôi đen ở app phía trước (dùng cho phím tắt ⌃⌥G, đăng ký trong `GlobalHotkeys`).
///
/// Giả lập ⌘C (cần quyền Accessibility), đọc clipboard, rồi khôi phục clipboard như cũ.
@MainActor
enum SelectionHotkey {
    /// Giả lập ⌘C, đợi clipboard đổi (tối đa 300 ms), đọc text rồi khôi phục clipboard.
    /// Trả về `nil` nếu không có đoạn nào được bôi đen.
    static func copySelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)
        let before = pasteboard.changeCount

        postCommandC()

        var copied: String?
        let deadline = Date().addingTimeInterval(0.3)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
            if pasteboard.changeCount != before {
                copied = pasteboard.string(forType: .string)
                break
            }
        }

        if pasteboard.changeCount != before {
            restore(saved, to: pasteboard)
        }
        return copied
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyC = CGKeyCode(kVK_ANSI_C)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        // Chỉ giữ Command, bỏ Control/Option người dùng đang giữ của phím tắt.
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private typealias Snapshot = [[(NSPasteboard.PasteboardType, Data)]]

    private static func snapshot(of pasteboard: NSPasteboard) -> Snapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
    }

    private static func restore(_ snapshot: Snapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = snapshot.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}
