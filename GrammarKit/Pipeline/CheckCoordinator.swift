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

/// Trạng thái của section "Bản dịch" trên panel.
public enum TranslationState: Equatable, Sendable {
    /// Không hiện section: tính năng tắt, hoặc chưa có kết quả sửa để dịch.
    case hidden
    case translating
    case done(String)
    case failed(String)
}

/// Nguồn của câu đang kiểm tra.
public enum TextSource: Equatable, Sendable {
    /// Câu chứa con trỏ trong ô đang focus.
    case focusedField
    /// Đoạn đang bôi đen trong ô đang focus (lấy tự động, không cần phím tắt).
    case selection
    case selectionHotkey
    case manual

    /// Đến từ cơ chế theo dõi ô đang focus: bị bỏ qua khi tạm dừng.
    var isTracked: Bool { self == .focusedField || self == .selection }

    /// Đoạn người dùng bôi đen: được kiểm tra cả khi ngắn (xem `LanguageGate`/`EditGuard` với `relaxed`).
    var isSelection: Bool { self == .selection || self == .selectionHotkey }
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

    /// Bản dịch tiếng Việt của câu đã sửa (hoặc câu gốc khi câu đúng).
    public private(set) var translation: TranslationState = .hidden

    /// Bật thì dịch mỗi kết quả "không có lỗi"/"có lỗi". Bật khi đang có kết quả thì dịch ngay;
    /// tắt thì huỷ bản dịch đang chạy và ẩn section.
    public var isTranslationEnabled = false {
        didSet {
            guard isTranslationEnabled != oldValue else { return }
            startTranslation()
        }
    }

    private var engine: (any GrammarEngine)?
    private var translator: (any TranslationEngine)?
    private var engineError: String?
    private let gate: LanguageGate
    private let editGuard: EditGuard
    private let debounce: Duration
    private var cache = ResultCache<CachedOutcome>(capacity: 200)
    private var pendingTask: Task<Void, Never>?
    private var translationCache = ResultCache<String>(capacity: 200)
    private var translationTask: Task<Void, Never>?

    /// Số lần thực sự gọi engine (dùng cho test).
    public private(set) var engineCallCount = 0

    private enum CachedOutcome: Sendable {
        case unchanged
        case corrected(String)
        case rewritten
    }

    public init(
        engine: (any GrammarEngine)? = nil,
        translator: (any TranslationEngine)? = nil,
        gate: LanguageGate = .init(),
        editGuard: EditGuard = .init(),
        debounce: Duration = .milliseconds(700)
    ) {
        self.engine = engine
        self.translator = translator
        self.gate = gate
        self.editGuard = editGuard
        self.debounce = debounce
        if engine == nil { state = .loadingModel }
    }

    public func setEngine(_ engine: any GrammarEngine, translator: (any TranslationEngine)? = nil) {
        self.engine = engine
        self.translator = translator
        engineError = nil
        if state == .loadingModel {
            if sentence.isEmpty { state = .idle } else { submit(sentence, from: source, immediately: true) }
        }
    }

    public func setEngineError(_ message: String) {
        engine = nil
        translator = nil
        engineError = message
        state = .modelError(message)
        cancelTranslation()
    }

    /// Nhận câu mới. Chờ `debounce` rồi mới kiểm tra, câu đến sau huỷ câu trước.
    public func submit(_ newSentence: String, from source: TextSource, immediately: Bool = false) {
        if isPaused && source.isTracked { return }

        let trimmed = newSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == sentence, !immediately, state != .idle, state != .loadingModel { return }

        sentence = trimmed
        self.source = source
        pendingTask?.cancel()
        cancelTranslation()

        let delay = immediately ? Duration.zero : debounce
        pendingTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.run(trimmed, relaxed: source.isSelection)
        }
    }

    /// Đợi lượt kiểm tra hiện tại xong (dùng cho test).
    public func waitForPendingCheck() async {
        await pendingTask?.value
        await translationTask?.value
    }

    private func run(_ text: String, relaxed: Bool) async {
        guard text == sentence else { return }

        if text.isEmpty {
            state = .idle
            return
        }

        switch gate.evaluate(text, relaxed: relaxed) {
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
            let outcome: CachedOutcome = switch editGuard.evaluate(diff, relaxed: relaxed) {
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
        startTranslation()
    }

    // MARK: - Dịch

    /// Câu cần dịch ứng với trạng thái hiện tại: câu đã sửa khi có lỗi, câu gốc khi câu đúng.
    private var translationTarget: String? {
        switch state {
        case let .ok(sentence): sentence
        case let .corrected(diff): diff.corrected
        default: nil
        }
    }

    private func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        translation = .hidden
    }

    /// Dịch câu ứng với trạng thái hiện tại, hoặc ẩn section nếu không có gì để dịch.
    private func startTranslation() {
        cancelTranslation()
        guard isTranslationEnabled, let translator, let target = translationTarget else { return }

        if let cached = translationCache.value(for: target) {
            translation = .done(cached)
            return
        }

        translation = .translating
        let source = sentence
        translationTask = Task { [weak self] in
            do {
                let result = try await translator.translate(target)
                guard let self else { return }
                self.translationCache.insert(result, for: target)
                guard self.isCurrent(source: source, target: target) else { return }
                self.translation = .done(result)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrent(source: source, target: target) else { return }
                self.translation = .failed(error.localizedDescription)
            }
        }
    }

    /// Bản dịch vừa xong vẫn khớp với câu đang hiển thị (không bị huỷ, câu chưa đổi, Dịch vẫn bật).
    private func isCurrent(source: String, target: String) -> Bool {
        !Task.isCancelled && isTranslationEnabled && sentence == source && translationTarget == target
    }
}
