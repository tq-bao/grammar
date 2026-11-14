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

    func testEngineErrorIsShown() async {
        let c = CheckCoordinator(engine: nil, debounce: .milliseconds(10))
        XCTAssertEqual(c.state, .loadingModel)
        c.setEngineError("Không tìm thấy model")
        c.submit("They was happy today.", from: .manual)
        await c.waitForPendingCheck()
        XCTAssertEqual(c.state, .modelError("Không tìm thấy model"))
    }
}
