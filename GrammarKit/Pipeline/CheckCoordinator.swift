import Foundation
import Observation

/// Trạng thái hiển thị trên panel.
public enum CheckState: Equatable, Sendable {
    /// Chưa có câu nào, hoặc câu quá ngắn nên không kiểm tra.
    case idle
    /// Đang nạp model, chưa kiểm tra được.
    case loadingModel
    case checking(String)
    case ok(String)
    case corrected(WordDiff)
    case notEnglish(String)
    /// Mô hình viết lại câu (EditGuard từ chối) nên không hiển thị kết quả.
    case uncertain(String)
    case modelError(String)
}

/// Nguồn của câu đang kiểm tra.
public enum TextSource: Equatable, Sendable {
    case focusedField
    case selectionHotkey
    case manual
}

/// Điều phối: debounce, lọc ngôn ngữ, cache, gọi engine, EditGuard.
@MainActor
@Observable
public final class CheckCoordinator {
    public private(set) var state: CheckState = .idle
    /// Câu đang hiển thị ở phần trên của panel.
    public private(set) var sentence: String = ""
    public private(set) var source: TextSource = .focusedField
    public var isPaused = false

    private var engine: (any GrammarEngine)?
    private var engineError: String?
    private let gate: LanguageGate
    private let editGuard: EditGuard
    private let debounce: Duration
    private var cache = ResultCache<CachedOutcome>(capacity: 200)
    private var pendingTask: Task<Void, Never>?

    /// Số lần thực sự gọi engine (dùng cho test).
    public private(set) var engineCallCount = 0

    private enum CachedOutcome: Sendable {
        case unchanged
        case corrected(String)
        case rewritten
    }

    public init(
        engine: (any GrammarEngine)? = nil,
        gate: LanguageGate = .init(),
        editGuard: EditGuard = .init(),
        debounce: Duration = .milliseconds(700)
    ) {
        self.engine = engine
        self.gate = gate
        self.editGuard = editGuard
        self.debounce = debounce
        if engine == nil { state = .loadingModel }
    }

    public func setEngine(_ engine: any GrammarEngine) {
        self.engine = engine
        engineError = nil
        if state == .loadingModel {
            if sentence.isEmpty { state = .idle } else { submit(sentence, from: source, immediately: true) }
        }
    }

    public func setEngineError(_ message: String) {
        engine = nil
        engineError = message
        state = .modelError(message)
    }

    /// Nhận câu mới. Chờ `debounce` rồi mới kiểm tra, câu đến sau huỷ câu trước.
    public func submit(_ newSentence: String, from source: TextSource, immediately: Bool = false) {
        if isPaused && source == .focusedField { return }

        let trimmed = newSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == sentence, !immediately, state != .idle, state != .loadingModel { return }

        sentence = trimmed
        self.source = source
        pendingTask?.cancel()

        let delay = immediately ? Duration.zero : debounce
        pendingTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.run(trimmed)
        }
    }

    /// Đợi lượt kiểm tra hiện tại xong (dùng cho test).
    public func waitForPendingCheck() async {
        await pendingTask?.value
    }

    private func run(_ text: String) async {
        guard text == sentence else { return }

        if text.isEmpty {
            state = .idle
            return
        }

        switch gate.evaluate(text) {
        case .tooShort:
            state = .idle
            return
        case .notEnglish:
            state = .notEnglish(text)
            return
        case .english:
            break
        }

        if let cached = cache.value(for: text) {
            apply(cached, for: text)
            return
        }

        guard let engine else {
            state = engineError.map(CheckState.modelError) ?? .loadingModel
            return
        }

        state = .checking(text)
        engineCallCount += 1
        do {
            // Bỏ qua khác biệt viết hoa/viết thường và dấu câu cuối câu.
            let corrected = CorrectionNormalizer.reconcile(original: text, corrected: try await engine.correct(text))
            // Câu đã thay đổi trong lúc đang kiểm tra -> bỏ kết quả cũ.
            guard !Task.isCancelled, text == sentence else { return }

            let diff = WordDiff(original: text, corrected: corrected)
            let outcome: CachedOutcome = switch editGuard.evaluate(diff) {
            case .unchanged: .unchanged
            case .accepted: .corrected(corrected)
            case .rewritten: .rewritten
            }
            cache.insert(outcome, for: text)
            apply(outcome, for: text)
        } catch is CancellationError {
            return
        } catch {
            guard text == sentence else { return }
            state = .modelError(error.localizedDescription)
        }
    }

    private func apply(_ outcome: CachedOutcome, for text: String) {
        switch outcome {
        case .unchanged:
            state = .ok(text)
        case let .corrected(corrected):
            state = .corrected(WordDiff(original: text, corrected: corrected))
        case .rewritten:
            state = .uncertain(text)
        }
    }
}
