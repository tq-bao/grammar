import XCTest
@testable import GrammarKit

final class CorrectionNormalizerTests: XCTestCase {
    private func reconcile(_ original: String, _ corrected: String) -> String {
        CorrectionNormalizer.reconcile(original: original, corrected: corrected)
    }

    func testKeepsUserCapitalizationAndNoFinalPeriod() {
        XCTAssertEqual(
            reconcile("yesterday i go to the office", "Yesterday I went to the office."),
            "yesterday i went to the office")
    }

    func testKeepsUserFinalPunctuation() {
        XCTAssertEqual(
            reconcile("She go to school yesterday,", "She went to school yesterday."),
            "She went to school yesterday,")
        XCTAssertEqual(
            reconcile("where is he going", "Where is he going?"),
            "where is he going")
        XCTAssertEqual(
            reconcile("They was happy!!", "They were happy."),
            "They were happy!!")
    }

    func testOnlyCaseAndFinalPunctuationDifferenceReturnsOriginal() {
        let original = "thanks, will check it tonight"
        XCTAssertEqual(reconcile(original, "Thanks, will check it tonight."), original)
        XCTAssertEqual(reconcile("i will call you after lunch.", "I will call you after lunch."),
                       "i will call you after lunch.")
    }

    func testRealFixesAreKeptAlongsideCaseDifferences() {
        XCTAssertEqual(
            reconcile("he have two cats and they is cute", "He has two cats and they are cute."),
            "he has two cats and they are cute")
    }

    func testMidSentenceCommaIsStillChecked() {
        // Dấu phẩy ở giữa câu vẫn là một chỉnh sửa.
        XCTAssertEqual(
            reconcile("ok I'll ping Minh about it", "Ok, I'll ping Minh about it."),
            "ok, I'll ping Minh about it")
    }

    func testInsertedWordKeepsModelText() {
        XCTAssertEqual(reconcile("i going home now.", "I am going home now."), "i am going home now.")
    }

    func testDiffAfterReconcileIsIdentical() {
        let corrected = reconcile("thanks, will check it tonight", "Thanks, will check it tonight.")
        XCTAssertTrue(WordDiff(original: "thanks, will check it tonight", corrected: corrected).isIdentical)
    }

    func testPunctuationOnlyInputs() {
        XCTAssertEqual(reconcile("...", "..."), "...")
        XCTAssertEqual(reconcile("hello there", "."), "hello there")
    }
}
