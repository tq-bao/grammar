import AppKit
import ApplicationServices
import GrammarKit

/// Theo dõi ô nhập liệu đang được focus ở app phía trước qua Accessibility API.
///
/// - Nghe `kAXFocusedUIElementChanged` trên app và `kAXValueChanged` / `kAXSelectedTextChanged`
///   trên ô đang focus.
/// - Không nhận được notification nào (nhiều app web/Electron không gửi) thì hỏi lại mỗi 500 ms.
/// - Bỏ qua ô mật khẩu và chính app này.
@MainActor
final class AXTextCapture {
    /// Gọi khi nội dung hoặc vị trí con trỏ của ô đang focus thay đổi.
    var onChange: ((_ text: String, _ cursorUTF16Offset: Int?) -> Void)?

    private var observer: AXObserver?
    private var appElement: AXUIElement?
    private var focusedElement: AXUIElement?
    private var currentPID: pid_t?
    private var lastEmitted: (text: String, cursor: Int?)?
    /// Ô đang focus có hỗ trợ text marker không (Chrome, Safari, Electron). `nil` = chưa kiểm tra.
    private var supportsTextMarkers: Bool?
    private var lastNotification = Date.distantPast
    private var pollTimer: Timer?
    private var activationToken: NSObjectProtocol?
    private(set) var isRunning = false

    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private static let pollInterval: TimeInterval = 0.5

    func start() {
        guard !isRunning else { return }
        isRunning = true

        activationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.attach(to: app) }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollIfNeeded() }
        }

        attach(to: NSWorkspace.shared.frontmostApplication)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let activationToken { NSWorkspace.shared.notificationCenter.removeObserver(activationToken) }
        activationToken = nil
        pollTimer?.invalidate()
        pollTimer = nil
        detach()
    }

    // MARK: - App

    private func attach(to app: NSRunningApplication?) {
        detach()
        guard let app, app.processIdentifier != ownPID else { return }

        let pid = app.processIdentifier
        ChromiumAccessibility.enableIfNeeded(for: app)

        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        appElement = element
        currentPID = pid

        var newObserver: AXObserver?
        guard AXObserverCreate(pid, axCallback, &newObserver) == .success, let newObserver else { return }
        observer = newObserver
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .defaultMode)
        AXObserverAddNotification(newObserver, element, kAXFocusedUIElementChangedNotification as CFString, refcon)

        updateFocusedElement()
    }

    private func detach() {
        if let observer {
            if let appElement {
                AXObserverRemoveNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString)
            }
            removeElementNotifications()
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        appElement = nil
        focusedElement = nil
        currentPID = nil
    }

    private var refcon: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    // MARK: - Focused element

    fileprivate func handle(notification: String) {
        lastNotification = Date()
        if notification == kAXFocusedUIElementChangedNotification as String {
            updateFocusedElement()
        } else {
            readFocusedElement()
        }
    }

    private func updateFocusedElement() {
        removeElementNotifications()
        focusedElement = nil
        supportsTextMarkers = nil
        lastNotification = .distantPast

        guard let appElement, let observer else { return }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return }
        let element = value as! AXUIElement  // đã kiểm tra type id ở trên
        focusedElement = element

        for name in [kAXValueChangedNotification, kAXSelectedTextChangedNotification] {
            AXObserverAddNotification(observer, element, name as CFString, refcon)
        }
        readFocusedElement()
    }

    private func removeElementNotifications() {
        guard let observer, let focusedElement else { return }
        for name in [kAXValueChangedNotification, kAXSelectedTextChangedNotification] {
            AXObserverRemoveNotification(observer, focusedElement, name as CFString)
        }
    }

    /// Ô không gửi notification thì hỏi lại định kỳ. Có cả trường hợp focus đổi mà app không báo.
    private func pollIfNeeded() {
        guard isRunning, Date().timeIntervalSince(lastNotification) > 1.0 else { return }
        if let appElement {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &value) == .success,
               let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                let element = value as! AXUIElement
                if focusedElement == nil || !CFEqual(element, focusedElement) {
                    updateFocusedElement()
                    return
                }
            }
        }
        readFocusedElement()
    }

    private func readFocusedElement() {
        guard let element = focusedElement else { return }
        guard !Self.isSecure(element) else { return }

        let text: String
        let cursor: Int?
        if let paragraph = paragraphAtCaret(of: element) {
            // Trình soạn thảo web: đọc đúng đoạn chứa con trỏ qua text marker.
            (text, cursor) = paragraph
        } else {
            // App gốc: AXValue + AXSelectedTextRange khớp nhau.
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
                  let fullText = value as? String else { return }
            text = fullText
            cursor = Self.cursorOffset(of: element)
        }

        if let lastEmitted, lastEmitted.text == text, lastEmitted.cursor == cursor { return }
        lastEmitted = (text, cursor)
        onChange?(text, cursor)
    }

    private static func isSecure(_ element: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subrole = subrole as? String, subrole == (kAXSecureTextFieldSubrole as String) {
            return true
        }
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let role = role as? String, role == "AXSecureTextField" {
            return true
        }
        return false
    }

    /// Đoạn văn chứa con trỏ và vị trí con trỏ trong đoạn, đọc qua text marker.
    ///
    /// Trong trình soạn thảo web có định dạng (ví dụ Confluence trên Chrome), `AXSelectedTextRange`
    /// bị lệch so với `AXValue` (lệch dồn theo code inline, phần tử lồng nhau…), còn text marker thì chính xác.
    /// Trả về `nil` nếu ô không hỗ trợ text marker, để dùng cách đọc cũ.
    private func paragraphAtCaret(of element: AXUIElement) -> (text: String, cursor: Int)? {
        if supportsTextMarkers == nil {
            var names: CFArray?
            let ok = AXUIElementCopyParameterizedAttributeNames(element, &names) == .success
            supportsTextMarkers = ok && ((names as? [String])?.contains(Self.paragraphForMarker) ?? false)
        }
        guard supportsTextMarkers == true else { return nil }

        var selection: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &selection) == .success,
              let selection, CFGetTypeID(selection) == AXTextMarkerRangeGetTypeID() else { return nil }
        let caret = AXTextMarkerRangeCopyStartMarker(selection as! AXTextMarkerRange)

        var paragraphRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
                element, Self.paragraphForMarker as CFString, caret, &paragraphRef) == .success,
              let paragraphRef, CFGetTypeID(paragraphRef) == AXTextMarkerRangeGetTypeID() else { return nil }
        let paragraphRange = paragraphRef as! AXTextMarkerRange
        guard let paragraph = Self.string(for: paragraphRange, in: element) else { return nil }

        let prefixRange = AXTextMarkerRangeCreate(nil, AXTextMarkerRangeCopyStartMarker(paragraphRange), caret)
        let prefix = Self.string(for: prefixRange, in: element) ?? ""
        return CaretContext.normalize(paragraph: paragraph, prefix: prefix)
    }

    private static let paragraphForMarker = "AXParagraphTextMarkerRangeForTextMarker"

    private static func string(for range: AXTextMarkerRange, in element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
                element, "AXStringForTextMarkerRange" as CFString, range, &value) == .success else { return nil }
        return value as? String
    }

    private static func cursorOffset(of element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range.location
    }
}

/// Callback C của AXObserver. Chạy trên main run loop (nơi đã add source).
private func axCallback(
    _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let name = notification as String
    // Truyền địa chỉ dưới dạng số để không bắt con trỏ non-Sendable vào closure.
    let address = UInt(bitPattern: refcon)
    MainActor.assumeIsolated {
        let pointer = UnsafeMutableRawPointer(bitPattern: address)!
        let capture = Unmanaged<AXTextCapture>.fromOpaque(pointer).takeUnretainedValue()
        capture.handle(notification: name)
    }
}
