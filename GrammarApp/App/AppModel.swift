import AppKit
import ApplicationServices
import GrammarKit
import Observation

/// Nối các phần của app: lấy text, pipeline kiểm tra, engine, panel, menu bar, cài đặt.
@MainActor
@Observable
final class AppModel {
    let coordinator = CheckCoordinator()
    let settings = PanelSettings()
    private(set) var isTrusted = AXIsProcessTrusted()
    private(set) var isPanelVisible = false
    private(set) var isPaused = false

    @ObservationIgnored private let capture = AXTextCapture()
    @ObservationIgnored private let hotkeys = GlobalHotkeys()
    @ObservationIgnored private var panel: CheckerPanel?
    @ObservationIgnored private var permissionTimer: Timer?

    func start() {
        capture.onChange = { [weak self] text, cursor, selection in
            // Đang bôi đen thì kiểm tra đúng đoạn bôi đen, không thì câu chứa con trỏ.
            guard let self,
                  let target = CheckTarget.resolve(text: text, cursorUTF16Offset: cursor, selection: selection)
            else { return }
            self.coordinator.submit(target.text, from: target.source)
        }
        hotkeys.register(.checkSelection) { [weak self] in
            Task { @MainActor in
                guard let text = await SelectionHotkey.copySelection(),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                self?.coordinator.submit(text, from: .selectionHotkey, immediately: true)
                self?.showPanel()
            }
        }
        hotkeys.register(.copyCorrection) { [weak self] in self?.copyCorrection() }

        showPanel()
        observeLayoutSettings()
        observeTranslationSetting()
        loadEngine()

        if isTrusted {
            capture.start()
        } else {
            requestAccessibility()
        }
    }

    // MARK: - Engine

    private func loadEngine() {
        let coordinator = coordinator
        Task.detached(priority: .userInitiated) {
            do {
                let url = try ModelLocator.locate()
                let engine = try LlamaGrammarEngine(modelURL: url)
                await engine.warmUp()
                await MainActor.run { coordinator.setEngine(engine, translator: engine) }
            } catch {
                let message = error.localizedDescription
                await MainActor.run { coordinator.setEngineError(message) }
            }
        }
    }

    // MARK: - Copy câu đã sửa

    /// Có câu sửa để copy (trạng thái "có lỗi").
    var canCopyCorrection: Bool {
        if case .corrected = coordinator.state { return true }
        return false
    }

    /// Copy câu đã sửa vào clipboard. Không làm gì nếu không có câu sửa.
    func copyCorrection() {
        guard case let .corrected(diff) = coordinator.state else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diff.corrected, forType: .string)
    }

    // MARK: - Quyền Accessibility

    private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        guard !isTrusted else {
            capture.start()
            return
        }
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted() else { return }
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.isTrusted = true
                if !self.isPaused { self.capture.start() }
            }
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Panel

    /// Đặt lại khung và chế độ chuột của panel khi đổi góc, độ rộng, click xuyên qua hoặc vị trí đã kéo.
    /// Độ mờ nền do SwiftUI tự vẽ lại.
    private func observeLayoutSettings() {
        withObservationTracking {
            _ = settings.corner
            _ = settings.width
            _ = settings.clickThrough
            _ = settings.customTopLeft
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.panel?.applyInteractionMode()
                self?.panel?.scheduleRelayout()
                self?.observeLayoutSettings()
            }
        }
    }

    /// Đồng bộ công tắc Dịch trong Cài đặt vào coordinator, và đặt lại khung panel
    /// vì section "Bản dịch" hiện/ẩn làm panel đổi chiều cao.
    private func observeTranslationSetting() {
        coordinator.isTranslationEnabled = withObservationTracking {
            settings.translationEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeTranslationSetting()
                self?.panel?.scheduleRelayout()
            }
        }
    }

    func togglePanel() {
        isPanelVisible ? hidePanel() : showPanel()
    }

    func showPanel() {
        if panel == nil {
            panel = CheckerPanel(rootView: TwoPaneView(model: self), settings: settings)
        }
        panel?.show()
        isPanelVisible = true
    }

    func hidePanel() {
        panel?.orderOut(nil)
        isPanelVisible = false
    }

    func togglePause() {
        isPaused.toggle()
        coordinator.isPaused = isPaused
        if isPaused {
            capture.stop()
        } else if isTrusted {
            capture.start()
        }
    }
}
