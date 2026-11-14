// Chẩn đoán (chỉ đọc): một app trả về gì qua Accessibility cho ô đang gõ.
//
//   swift scripts/ax-probe.swift com.google.Chrome   chờ tới khi Chrome ở phía trước, đợi thêm 3 giây rồi đọc
//   swift scripts/ax-probe.swift 10                  chờ 10 giây rồi đọc app đang ở phía trước (mặc định 5)
//
// Chạy lệnh, chuyển sang app cần kiểm tra và đặt con trỏ vào ô đang gõ. Script đọc ô đang focus
// của app ở phía trước và in ra:
//   - loại ô, độ dài AXValue, vị trí con trỏ AXSelectedTextRange và đoạn text quanh vị trí đó
//     (cách đọc cho app gốc);
//   - đoạn văn chứa con trỏ và vị trí con trỏ trong đoạn qua text marker
//     (cách đọc cho Chrome, Safari, Electron).
// Nếu đoạn text quanh AXSelectedTextRange không phải chỗ bạn đang gõ, nghĩa là app báo vị trí con trỏ lệch,
// và Grammar cần dùng text marker cho app đó.
// Script không thay đổi gì và không lưu nội dung. Terminal hoặc IDE chạy lệnh cần có quyền Accessibility.
import AppKit
import ApplicationServices

let argument = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "5"
guard AXIsProcessTrusted() else {
    print("Tiến trình này chưa có quyền Accessibility (System Settings › Privacy & Security › Accessibility).")
    exit(1)
}
if let seconds = Double(argument) {
    print("Chuyển sang app cần kiểm tra và đặt con trỏ vào ô đang gõ. Đọc sau \(Int(seconds)) giây…")
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
} else {
    print("Chờ \(argument) được đưa lên trước…")
    // Chạy run loop để frontmostApplication được cập nhật.
    while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != argument {
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }
    print("Đặt con trỏ vào ô đang gõ, đọc sau 3 giây…")
    RunLoop.current.run(until: Date().addingTimeInterval(3))
}

func attr(_ e: AXUIElement, _ n: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil
}
func pattr(_ e: AXUIElement, _ n: String, _ p: CFTypeRef) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyParameterizedAttributeValue(e, n as CFString, p, &v) == .success ? v : nil
}

guard let front = NSWorkspace.shared.frontmostApplication else { print("Không xác định được app phía trước"); exit(1) }
print("App:", front.localizedName ?? "?", "(\(front.bundleIdentifier ?? "?"))")
let appElement = AXUIElementCreateApplication(front.processIdentifier)
guard let focused = attr(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute)
        ?? attr(appElement, kAXFocusedUIElementAttribute) else {
    print("Không có ô nào đang focus"); exit(1)
}
let element = focused as! AXUIElement
print("Loại ô:", attr(element, kAXRoleAttribute) ?? "?", "/", attr(element, kAXSubroleAttribute) ?? "-")

print("\n[Cách đọc cho app gốc]")
let value = attr(element, kAXValueAttribute) as? String ?? ""
print("Độ dài AXValue:", value.utf16.count)
if let v = attr(element, kAXSelectedTextRangeAttribute), CFGetTypeID(v) == AXValueGetTypeID() {
    var range = CFRange()
    AXValueGetValue(v as! AXValue, .cfRange, &range)
    let ns = value as NSString
    let start = max(0, min(range.location, ns.length) - 30)
    let snippet = ns.substring(with: NSRange(location: start, length: min(60, ns.length - start)))
    print("AXSelectedTextRange:", range.location, "| text quanh vị trí đó:", snippet.debugDescription)
} else {
    print("AXSelectedTextRange: không có")
}

print("\n[Cách đọc qua text marker]")
guard let selection = attr(element, "AXSelectedTextMarkerRange"),
      CFGetTypeID(selection) == AXTextMarkerRangeGetTypeID() else {
    print("Không hỗ trợ text marker"); exit(0)
}
let caret = AXTextMarkerRangeCopyStartMarker(selection as! AXTextMarkerRange)
guard let paragraphRef = pattr(element, "AXParagraphTextMarkerRangeForTextMarker", caret),
      CFGetTypeID(paragraphRef) == AXTextMarkerRangeGetTypeID() else {
    print("Không đọc được đoạn văn tại con trỏ"); exit(0)
}
let paragraphRange = paragraphRef as! AXTextMarkerRange
let paragraph = pattr(element, "AXStringForTextMarkerRange", paragraphRange) as? String ?? ""
let prefixRange = AXTextMarkerRangeCreate(nil, AXTextMarkerRangeCopyStartMarker(paragraphRange), caret)
let prefix = pattr(element, "AXStringForTextMarkerRange", prefixRange) as? String ?? ""
print("Đoạn chứa con trỏ:", paragraph.debugDescription)
print("Vị trí con trỏ trong đoạn:", prefix.utf16.count, "/", paragraph.utf16.count)
