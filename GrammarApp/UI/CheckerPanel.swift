import AppKit
import GrammarKit
import SwiftUI

/// Panel chỉ để xem: nền trong suốt (vẽ bởi SwiftUI), không bao giờ nhận focus.
///
/// - Header (dải trên cùng): luôn nhận chuột, kéo để dời panel.
/// - Phần nội dung: click xuyên qua khi bật (mặc định); khi tắt thì kéo được ở bất kỳ đâu.
///
/// `ignoresMouseEvents` áp dụng cho cả cửa sổ, nên panel theo dõi vị trí chuột và chỉ nhận chuột
/// khi chuột đang ở trên header (hoặc khi tắt click xuyên qua).
/// Vị trí lấy từ vị trí đã kéo (nếu có) hoặc góc đã chọn; chiều cao co theo nội dung.
final class CheckerPanel: NSPanel {
    private let settings: PanelSettings
    private let hostingView: AutoSizingHostingView<AnyView>
    private var relayoutScheduled = false
    /// Đang đặt khung từ `relayout()`, để phân biệt với người dùng kéo.
    private var isApplyingLayout = false
    private var globalMouseMonitor: Any?

    @MainActor
    init<Content: View>(rootView: Content, settings: PanelSettings) {
        self.settings = settings
        hostingView = AutoSizingHostingView(rootView: AnyView(rootView))
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: settings.width, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        acceptsMouseMovedEvents = true

        hostingView.sizingOptions = [.intrinsicContentSize]
        hostingView.onIntrinsicSizeChange = { [weak self] in self?.scheduleRelayout() }
        hostingView.onMouseActivity = { [weak self] in self?.updateMouseInteraction() }
        contentView = hostingView

        // Observer dạng selector tự được gỡ khi panel bị huỷ.
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(didMove),
            name: NSWindow.didMoveNotification, object: self)

        // Chuột di chuyển trên app khác (lúc panel đang bỏ qua chuột): xem có đang vào header không.
        // Monitor chuột không cần quyền gì thêm. Handler chạy trên main thread.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMouseInteraction() }
        }

        // Vị trí giờ do cài đặt quyết định; xoá khung autosave của phiên bản cũ.
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame GrammarCheckerPanel")
        applyInteractionMode()
        relayout()
    }

    @MainActor @objc private func screenParametersChanged() {
        scheduleRelayout()
    }

    /// Người dùng kéo panel xong (không phải do `relayout()`): lưu vị trí góc trên trái.
    @MainActor @objc private func didMove() {
        guard !isApplyingLayout else { return }
        settings.customTopLeft = CGPoint(x: frame.minX, y: frame.maxY)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Hiện panel mà không lấy focus.
    @MainActor
    func show() {
        relayout()
        orderFrontRegardless()
        updateMouseInteraction()
    }

    /// Áp dụng chế độ click xuyên qua / kéo được theo cài đặt.
    @MainActor
    func applyInteractionMode() {
        hostingView.isDraggable = !settings.clickThrough
        updateMouseInteraction()
    }

    /// Chỉ nhận chuột khi chuột ở trên header, hoặc khi đã tắt click xuyên qua.
    @MainActor
    func updateMouseInteraction() {
        let overHeader = isVisible && PanelLayout.headerRect(in: frame).contains(NSEvent.mouseLocation)
        let shouldIgnore = settings.clickThrough && !overHeader
        if ignoresMouseEvents != shouldIgnore {
            ignoresMouseEvents = shouldIgnore
        }
        if overHeader || !settings.clickThrough {
            NSCursor.openHand.set()
        }
    }

    /// Gom nhiều lần thay đổi kích thước nội dung thành một lần đặt lại khung.
    @MainActor
    func scheduleRelayout() {
        guard !relayoutScheduled else { return }
        relayoutScheduled = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.relayoutScheduled = false
                self?.relayout()
            }
        }
    }

    @MainActor
    func relayout() {
        let size = CGSize(width: settings.width, height: max(hostingView.fittingSize.height, 60))
        let target: CGRect
        if let topLeft = settings.customTopLeft {
            // Màn hình chứa vị trí đã kéo; không còn màn hình đó thì dùng màn hình chính.
            let probe = CGPoint(x: topLeft.x, y: topLeft.y - 1)
            let screen = NSScreen.screens.first { $0.frame.contains(probe) } ?? NSScreen.screens.first
            guard let visible = screen?.visibleFrame else { return }
            target = PanelLayout.frame(topLeft: topLeft, size: size, visibleFrame: visible)
        } else {
            guard let visible = NSScreen.screens.first?.visibleFrame else { return }
            target = PanelLayout.frame(corner: settings.corner, size: size, visibleFrame: visible)
        }
        if frame != target {
            isApplyingLayout = true
            setFrame(target, display: true)
            isApplyingLayout = false
        }
    }
}

/// Báo ra ngoài mỗi khi SwiftUI đổi kích thước nội dung, và cho kéo cửa sổ bằng header
/// (hoặc toàn bộ panel khi `isDraggable`).
final class AutoSizingHostingView<Content: View>: NSHostingView<Content> {
    var onIntrinsicSizeChange: (() -> Void)?
    /// Chuột di chuyển hoặc ra/vào view: panel tính lại có nhận chuột hay không.
    var onMouseActivity: (() -> Void)?
    /// Khi `true`, nhấn giữ chuột ở bất kỳ đâu trên panel để kéo panel.
    var isDraggable = false

    private var trackingArea: NSTrackingArea?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIntrinsicSizeChange?()
    }

    /// Điểm (toạ độ của superview, tức toạ độ cửa sổ) có nằm trong dải header không.
    private func isInHeader(_ pointInWindow: NSPoint) -> Bool {
        guard let window else { return false }
        let windowBounds = CGRect(origin: .zero, size: window.frame.size)
        return PanelLayout.headerRect(in: windowBounds).contains(pointInWindow)
    }

    // Nội dung chỉ để xem: nhận chuột ở header (hoặc toàn bộ khi kéo được), còn lại không nhận gì.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point), isDraggable || isInHeader(point) else { return nil }
        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        if isDraggable || isInHeader(event.locationInWindow) {
            window.performDrag(with: event)
        }
        // Chuột rơi xuống phần nội dung trước khi kịp bật lại click xuyên qua: bỏ qua click này.
        onMouseActivity?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) { onMouseActivity?() }
    override func mouseEntered(with event: NSEvent) { onMouseActivity?() }
    override func mouseExited(with event: NSEvent) { onMouseActivity?() }

    override func cursorUpdate(with event: NSEvent) {
        if isDraggable || isInHeader(event.locationInWindow) {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}
