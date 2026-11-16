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
    private(set) var modelStatus: ModelStatus = .loading

    @ObservationIgnored private let capture = AXTextCapture()
    @ObservationIgnored private let hotkeys = GlobalHotkeys()
    @ObservationIgnored private var panel: CheckerPanel?
    @ObservationIgnored private var permissionTimer: Timer?
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    /// Đã hỏi tải model trong phiên này chưa (chỉ hỏi một lần mỗi lần mở app).
    @ObservationIgnored private var hasPromptedForDownload = false

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

    /// Nạp model nếu đã có trên máy. Chưa có thì hỏi người dùng có tải không.
    private func loadEngine() {
        modelStatus = .loading
        coordinator.setLoadingModel()
        let coordinator = coordinator
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let url = try ModelLocator.locate()
                let engine = try LlamaGrammarEngine(modelURL: url)
                await engine.warmUp()
                await MainActor.run {
                    coordinator.setEngine(engine, translator: engine)
                    self?.modelStatus = .ready
                }
            } catch GrammarEngineError.modelNotFound(let name) where name == ModelLocator.defaultModelFileName {
                await MainActor.run { self?.handleMissingModel(prompt: true) }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    coordinator.setEngineError(message)
                    self?.modelStatus = .loadFailed(message)
                }
            }
        }
    }

    // MARK: - Tải model

    /// Chưa có model: panel báo cần tải, menu bar có mục tải. Lần đầu trong phiên thì hỏi bằng hộp thoại.
    private func handleMissingModel(prompt: Bool) {
        let partial = ModelLocator.downloadDestination().map(ModelDownloader.partialBytes(for:)) ?? 0
        modelStatus = .missing(partialBytes: partial)
        coordinator.setModelMissing()
        if prompt, !hasPromptedForDownload {
            hasPromptedForDownload = true
            // Chạy hộp thoại modal ở lượt sau, không chạy lồng trong task nạp model.
            Task { @MainActor [weak self] in self?.promptForDownload(partialBytes: partial) }
        }
    }

    private func promptForDownload(partialBytes: Int64) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Tải model ngôn ngữ cho Grammar?"
        var info = "Grammar kiểm tra ngữ pháp bằng model Qwen2.5-7B chạy ngay trên máy. "
            + "Model chỉ tải một lần từ Hugging Face "
            + "và được lưu ở ~/Library/Application Support/Grammar/Models.\n\n"
            + "Sau khi tải, app chạy hoàn toàn offline. Nội dung bạn gõ không bao giờ được gửi đi."
        if partialBytes > 0 {
            let percent = TwoPaneView.percent(partialBytes, ModelLocator.defaultModelSize)
            info += "\n\nLần trước đã tải được \(percent)%. App sẽ tải tiếp từ chỗ đó."
        }
        alert.informativeText = info
        alert.addButton(withTitle: partialBytes > 0 ? "Tải tiếp" : "Tải ngay")
        alert.addButton(withTitle: "Để sau")

        // App không có Dock icon nên phải tự đưa hộp thoại lên trước.
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            downloadModel()
        }
    }

    /// Bắt đầu (hoặc tải tiếp) model mặc định. Tải xong thì nạp model ngay.
    func downloadModel() {
        guard downloadTask == nil, let destination = ModelLocator.downloadDestination() else { return }
        let downloader = ModelDownloader(destination: destination)
        let total = ModelLocator.defaultModelSize
        applyDownloadEvent(.progress(received: ModelDownloader.partialBytes(for: destination), total: total), force: true)

        downloadTask = Task { [weak self] in
            do {
                try await downloader.download { event in
                    Task { @MainActor in self?.applyDownloadEvent(event) }
                }
                guard let self else { return }
                self.downloadTask = nil
                self.loadEngine()
            } catch is CancellationError {
                guard let self else { return }
                self.downloadTask = nil
                self.handleMissingModel(prompt: false)
            } catch {
                guard let self else { return }
                self.downloadTask = nil
                let message = error.localizedDescription
                self.modelStatus = .failed(message)
                self.coordinator.setEngineError(message)
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    private func applyDownloadEvent(_ event: ModelDownloadEvent, force: Bool = false) {
        // Sự kiện đến muộn sau khi đã huỷ hoặc tải xong thì bỏ qua.
        guard force || downloadTask != nil else { return }
        switch event {
        case let .progress(received, total):
            modelStatus = .downloading(received: received, total: total)
            coordinator.setModelDownloadProgress(received: received, total: total)
        case .verifying:
            modelStatus = .verifying
            coordinator.setVerifyingModel()
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

/// Trạng thái model, dùng cho các mục trên menu bar.
enum ModelStatus: Equatable {
    /// Đang nạp model vào bộ nhớ.
    case loading
    case ready
    /// Chưa có model. `partialBytes` > 0 nếu đã tải dở ở lần trước.
    case missing(partialBytes: Int64)
    case downloading(received: Int64, total: Int64)
    case verifying
    /// Tải model thất bại, có thể thử lại.
    case failed(String)
    /// Có file model nhưng không nạp được.
    case loadFailed(String)
}
