import XCTest
@testable import GrammarKit

final class SentenceExtractorTests: XCTestCase {
    let text = "I like tea. He have two cats. We are fine."

    private func offset(of needle: String) -> Int {
        text.utf16.distance(from: text.startIndex, to: text.range(of: needle)!.lowerBound)
    }

    func testCursorInSecondSentence() {
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: offset(of: "two")), "He have two cats.")
    }

    func testCursorInFirstSentence() {
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: 2), "I like tea.")
    }

    func testCursorAtEndOfText() {
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: text.utf16.count), "We are fine.")
    }

    func testNoCursorUsesLastSentence() {
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: nil), "We are fine.")
    }

    func testOutOfRangeCursorIsClamped() {
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: 10_000), "We are fine.")
    }

    func testEmptyText() {
        XCTAssertNil(SentenceExtractor.sentence(in: "   \n", cursorUTF16Offset: 0))
    }

    func testEmojiBeforeCursorUsesUTF16Offsets() {
        let t = "Nice 😀 day. She go home now."
        let cursor = t.utf16.count - 2
        XCTAssertEqual(SentenceExtractor.sentence(in: t, cursorUTF16Offset: cursor), "She go home now.")
    }
}

final class LanguageGateTests: XCTestCase {
    let gate = LanguageGate()

    func testEnglish() {
        XCTAssertEqual(gate.evaluate("She go to school yesterday."), .english)
        XCTAssertEqual(gate.evaluate("He have two cats and they is cute."), .english)
    }

    func testVietnamese() {
        XCTAssertEqual(gate.evaluate("Hôm nay tôi đi học muộn."), .notEnglish)
    }

    func testTooShort() {
        XCTAssertEqual(gate.evaluate("ok thanks"), .tooShort)
        XCTAssertEqual(gate.evaluate("👍 !!"), .tooShort)
    }

    func testEnglishWithVietnameseNames() {
        XCTAssertEqual(gate.evaluate("Hi, my name is Bao"), .english)
        XCTAssertEqual(gate.evaluate("ok I will ping Tuan"), .english)
        XCTAssertEqual(gate.evaluate("my name is Bao"), .english)
        XCTAssertEqual(gate.evaluate("Hi Minh, can you check the PR?"), .english)
    }

    func testVietnameseWithoutDiacritics() {
        XCTAssertEqual(gate.evaluate("hom nay toi di hoc muon"), .notEnglish)
        XCTAssertEqual(gate.evaluate("anh check giup em cai PR nay nhe"), .notEnglish)
        XCTAssertEqual(gate.evaluate("Bao oi, an com chua"), .notEnglish)
    }

    func testOtherLanguages() {
        XCTAssertEqual(gate.evaluate("Danke schön, wir sehen uns morgen"), .notEnglish)
        XCTAssertEqual(gate.evaluate("Je suis très fatigué aujourd'hui"), .notEnglish)
    }

    func testMixedMostlyVietnamese() {
        XCTAssertEqual(gate.evaluate("Anh gửi em cái file report nhé, cảm ơn anh nhiều."), .notEnglish)
    }

    // MARK: - Đoạn bôi đen

    func testRelaxedAcceptsSingleWord() {
        XCTAssertEqual(gate.evaluate("recieve", relaxed: true), .english)
        XCTAssertEqual(gate.evaluate("ok thanks", relaxed: true), .english)
        XCTAssertEqual(gate.evaluate("recieve"), .tooShort)
    }

    func testRelaxedStillDetectsLanguageFromThreeWords() {
        XCTAssertEqual(gate.evaluate("Hôm nay tôi đi học muộn.", relaxed: true), .notEnglish)
        XCTAssertEqual(gate.evaluate("She go to school yesterday.", relaxed: true), .english)
    }

    func testRelaxedRejectsNoWords() {
        XCTAssertEqual(gate.evaluate("   ", relaxed: true), .tooShort)
        XCTAssertEqual(gate.evaluate("👍 !!", relaxed: true), .tooShort)
    }
}

final class ResultCacheTests: XCTestCase {
    func testHitWithNormalizedWhitespace() {
        var cache = ResultCache<String>(capacity: 2)
        cache.insert("x", for: "He  have cats ")
        XCTAssertEqual(cache.value(for: "He have cats"), "x")
    }

    func testEvictsLeastRecentlyUsed() {
        var cache = ResultCache<Int>(capacity: 2)
        cache.insert(1, for: "a")
        cache.insert(2, for: "b")
        _ = cache.value(for: "a")  // "a" mới dùng, "b" thành cũ nhất
        cache.insert(3, for: "c")
        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.value(for: "b"))
        XCTAssertEqual(cache.value(for: "a"), 1)
        XCTAssertEqual(cache.value(for: "c"), 3)
    }
}

/// Engine giả: trả kết quả theo bảng, có độ trễ cấu hình được.
actor FakeEngine: GrammarEngine {
    var answers: [String: String]
    let delay: Duration
    private(set) var calls: [String] = []

    init(answers: [String: String], delay: Duration = .zero) {
        self.answers = answers
        self.delay = delay
    }

    func correct(_ sentence: String) async throws -> String {
        calls.append(sentence)
        if delay > .zero { try await Task.sleep(for: delay) }
        return answers[sentence] ?? sentence
    }
}

@MainActor
final class CheckCoordinatorTests: XCTestCase {
    func makeCoordinator(_ engine: FakeEngine) -> CheckCoordinator {
        CheckCoordinator(engine: engine, debounce: .milliseconds(80))
    }

    func testCorrectsAfterDebounce() async {
        let engine = FakeEngine(answers: ["She go to school yesterday.": "She went to school yesterday."])
        let c = makeCoordinator(engine)
        c.submit("She go to school yesterday.", from: .focusedField)
        await c.waitForPendingCheck()
        guard case let .corrected(diff) = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(diff.removedWords, ["go"])
        XCTAssertEqual(diff.corrected, "She went to school yesterday.")
    }

    func testTypingContinuouslyDoesNotCallEngine() async throws {
        let engine = FakeEngine(answers: [:])
        let c = makeCoordinator(engine)
        for partial in ["She go", "She go to", "She go to school", "She go to school today"] {
            c.submit(partial, from: .focusedField)
            try await Task.sleep(for: .milliseconds(20))
        }
        let callsWhileTyping = await engine.calls.count
        XCTAssertEqual(callsWhileTyping, 0)
        await c.waitForPendingCheck()
        let calls = await engine.calls
        XCTAssertEqual(calls, ["She go to school today"])
    }

    func testStaleResultIsDropped() async throws {
        let engine = FakeEngine(
            answers: ["They was happy today.": "They were happy today.", "We is ready now.": "We are ready now."],
            delay: .milliseconds(150))
        let c = makeCoordinator(engine)
        c.submit("They was happy today.", from: .focusedField)
        try await Task.sleep(for: .milliseconds(120))  // engine đang chạy câu 1
        c.submit("We is ready now.", from: .focusedField)
        try await Task.sleep(for: .milliseconds(60))   // câu 1 xong, nhưng không được hiển thị
        if case let .corrected(diff) = c.state {
            XCTAssertNotEqual(diff.original, "They was happy today.")
        }
        await c.waitForPendingCheck()
        guard case let .corrected(diff) = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(diff.original, "We is ready now.")
    }

    func testCacheHitSkipsEngine() async {
        let engine = FakeEngine(answers: ["They was happy today.": "They were happy today."])
        let c = makeCoordinator(engine)
        c.submit("They was happy today.", from: .focusedField)
        await c.waitForPendingCheck()
        c.submit("We are fine here.", from: .focusedField)
        await c.waitForPendingCheck()
        c.submit("They was happy today.", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.engineCallCount, 2)
        guard case .corrected = c.state else { return XCTFail("state = \(c.state)") }
    }

    func testCorrectSentenceIsOk() async {
        let c = makeCoordinator(FakeEngine(answers: [:]))
        c.submit("I have finished the report.", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .ok("I have finished the report."))
    }

    func testCaseAndFinalPunctuationDifferencesAreOk() async {
        let engine = FakeEngine(answers: ["thanks, will check it tonight": "Thanks, will check it tonight."])
        let c = makeCoordinator(engine)
        c.submit("thanks, will check it tonight", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .ok("thanks, will check it tonight"))
    }

    func testRealFixKeepsUserCapitalization() async {
        let engine = FakeEngine(answers: ["yesterday i go to the office": "Yesterday I went to the office."])
        let c = makeCoordinator(engine)
        c.submit("yesterday i go to the office", from: .focusedField)
        await c.waitForPendingCheck()
        guard case let .corrected(diff) = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(diff.corrected, "yesterday i went to the office")
        XCTAssertEqual(diff.removedWords, ["go"])
    }

    func testVietnameseIsNotChecked() async {
        let engine = FakeEngine(answers: [:])
        let c = makeCoordinator(engine)
        c.submit("Hôm nay tôi đi học muộn.", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .notEnglish("Hôm nay tôi đi học muộn."))
        XCTAssertEqual(c.engineCallCount, 0)
    }

    func testRewriteIsUncertain() async {
        let engine = FakeEngine(answers: [
            "gonna send u the file tmr, it have the numbers":
                "I will send you the document tomorrow; it contains the figures.",
        ])
        let c = makeCoordinator(engine)
        c.submit("gonna send u the file tmr, it have the numbers", from: .manual)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .uncertain("gonna send u the file tmr, it have the numbers"))
    }

    func testPausedIgnoresFocusedFieldButNotManual() async {
        let c = makeCoordinator(FakeEngine(answers: [:]))
        c.isPaused = true
        c.submit("I have finished the report.", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .idle)
        c.submit("I have finished the report.", from: .manual)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .ok("I have finished the report."))
    }

    // MARK: - Đoạn bôi đen

    func testSelectionChecksSingleWord() async {
        let engine = FakeEngine(answers: ["recieve": "receive"])
        let c = makeCoordinator(engine)
        c.submit("recieve", from: .selection)
        await c.waitForPendingCheck()
        guard case let .corrected(diff) = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(diff.corrected, "receive")
        XCTAssertEqual(c.source, .selection)
    }

    func testFocusedFieldSingleWordIsNotChecked() async {
        let engine = FakeEngine(answers: ["recieve": "receive"])
        let c = makeCoordinator(engine)
        c.submit("recieve", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .idle)
        let calls = await engine.calls
        XCTAssertEqual(calls, [])
    }

    func testSelectionHotkeyChecksSingleWord() async {
        let c = makeCoordinator(FakeEngine(answers: ["recieve": "receive"]))
        c.submit("recieve", from: .selectionHotkey, immediately: true)
        await c.waitForPendingCheck()
        guard case let .corrected(diff) = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(diff.corrected, "receive")
    }

    func testPausedIgnoresSelection() async {
        let engine = FakeEngine(answers: ["recieve": "receive"])
        let c = makeCoordinator(engine)
        c.isPaused = true
        c.submit("recieve", from: .selection)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .idle)
        XCTAssertEqual(c.sentence, "")
        let calls = await engine.calls
        XCTAssertEqual(calls, [])
    }

    func testEngineErrorIsShown() async {
        let c = CheckCoordinator(engine: nil, debounce: .milliseconds(10))
        XCTAssertEqual(c.state, .loadingModel)
        c.setEngineError("Không tìm thấy model")
        c.submit("They was happy today.", from: .manual)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .modelError("Không tìm thấy model"))
    }
}

/// Bộ dịch giả: trả "VI: <câu>", có độ trễ và chế độ ném lỗi.
/// Độ trễ bỏ qua việc huỷ để kiểm tra coordinator tự bỏ kết quả cũ.
actor FakeTranslator: TranslationEngine {
    struct Failure: LocalizedError {
        var errorDescription: String? { "Model gặp lỗi khi dịch." }
    }

    let delay: Duration
    let fails: Bool
    private(set) var calls: [String] = []

    init(delay: Duration = .zero, fails: Bool = false) {
        self.delay = delay
        self.fails = fails
    }

    func translate(_ sentence: String) async throws -> String {
        calls.append(sentence)
        if delay > .zero { try? await Task.sleep(for: delay) }
        if fails { throw Failure() }
        return "VI: \(sentence)"
    }
}

@MainActor
final class CheckCoordinatorTranslationTests: XCTestCase {
    let wrong = "She go to school yesterday."
    let fixed = "She went to school yesterday."

    func makeCoordinator(
        translator: FakeTranslator, enabled: Bool = true, answers: [String: String]? = nil
    ) -> CheckCoordinator {
        let engine = FakeEngine(answers: answers ?? [wrong: fixed])
        let c = CheckCoordinator(engine: engine, translator: translator, debounce: .milliseconds(80))
        c.isTranslationEnabled = enabled
        return c
    }

    func testDisabledHidesSectionAndNeverTranslates() async {
        let translator = FakeTranslator()
        let c = makeCoordinator(translator: translator, enabled: false)
        c.submit(wrong, from: .focusedField)
        await c.waitForPendingCheck()
        guard case .corrected = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(c.translation, .hidden)
        let calls = await translator.calls
        XCTAssertEqual(calls, [])
    }

    func testCorrectedTranslatesCorrectedSentence() async {
        let translator = FakeTranslator()
        let c = makeCoordinator(translator: translator)
        c.submit(wrong, from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .done("VI: \(fixed)"))
        let calls = await translator.calls
        XCTAssertEqual(calls, [fixed])
    }

    func testOkTranslatesOriginalSentence() async {
        let translator = FakeTranslator()
        let c = makeCoordinator(translator: translator)
        c.submit("I have finished the report.", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .ok("I have finished the report."))
        XCTAssertEqual(c.translation, .done("VI: I have finished the report."))
    }

    func testShowsTranslatingBeforeResult() async throws {
        let translator = FakeTranslator(delay: .milliseconds(200))
        let c = makeCoordinator(translator: translator)
        c.submit(wrong, from: .focusedField)
        try await Task.sleep(for: .milliseconds(150))
        guard case .corrected = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(c.translation, .translating)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .done("VI: \(fixed)"))
    }

    func testNotEnglishAndUncertainHideSection() async {
        let translator = FakeTranslator()
        let rewrite = "gonna send u the file tmr, it have the numbers"
        let c = makeCoordinator(translator: translator, answers: [
            rewrite: "I will send you the document tomorrow; it contains the figures.",
        ])
        c.submit("Hôm nay tôi đi học muộn.", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .hidden)

        c.submit(rewrite, from: .manual)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .uncertain(rewrite))
        XCTAssertEqual(c.translation, .hidden)

        let calls = await translator.calls
        XCTAssertEqual(calls, [])
    }

    func testStaleTranslationIsNeverShown() async throws {
        let translator = FakeTranslator(delay: .milliseconds(150))
        let c = makeCoordinator(translator: translator)
        c.submit(wrong, from: .focusedField)
        try await Task.sleep(for: .milliseconds(120))  // đang dịch câu 1
        XCTAssertEqual(c.translation, .translating)
        c.submit("We are ready now.", from: .focusedField)
        XCTAssertEqual(c.translation, .hidden)
        try await Task.sleep(for: .milliseconds(160))  // bản dịch câu 1 đã xong, câu 2 đang dịch
        XCTAssertNotEqual(c.translation, .done("VI: \(fixed)"))
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .done("VI: We are ready now."))
    }

    func testCachedTranslationIsReused() async {
        let translator = FakeTranslator()
        let c = makeCoordinator(translator: translator)
        c.submit("I have finished the report.", from: .focusedField)
        await c.waitForPendingCheck()
        c.submit("We are ready now.", from: .focusedField)
        await c.waitForPendingCheck()
        c.submit("I have finished the report.", from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .done("VI: I have finished the report."))
        let calls = await translator.calls
        XCTAssertEqual(calls, ["I have finished the report.", "We are ready now."])
    }

    func testEnablingTranslatesCurrentResult() async {
        let translator = FakeTranslator()
        let c = makeCoordinator(translator: translator, enabled: false)
        c.submit(wrong, from: .focusedField)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .hidden)
        c.isTranslationEnabled = true
        XCTAssertEqual(c.translation, .translating)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .done("VI: \(fixed)"))
    }

    func testDisablingWhileTranslatingHidesSection() async throws {
        let translator = FakeTranslator(delay: .milliseconds(150))
        let c = makeCoordinator(translator: translator)
        c.submit(wrong, from: .focusedField)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(c.translation, .translating)
        c.isTranslationEnabled = false
        XCTAssertEqual(c.translation, .hidden)
        try await Task.sleep(for: .milliseconds(100))
        await c.waitForPendingCheck()
        XCTAssertEqual(c.translation, .hidden)
    }

    func testTranslationErrorKeepsCorrection() async {
        let c = makeCoordinator(translator: FakeTranslator(fails: true))
        c.submit(wrong, from: .focusedField)
        await c.waitForPendingCheck()
        guard case let .corrected(diff) = c.state else { return XCTFail("state = \(c.state)") }
        XCTAssertEqual(diff.corrected, fixed)
        XCTAssertEqual(c.translation, .failed("Model gặp lỗi khi dịch."))
    }
}
