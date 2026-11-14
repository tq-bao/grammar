import XCTest
@testable import GrammarKit

final class TokenizerTests: XCTestCase {
    func testApostrophesStayInsideWords() {
        let tokens = WordTokenizer.tokenize("I don't know, it's fine.")
        XCTAssertEqual(tokens.map(\.text), ["I", "don't", "know", ",", "it's", "fine", "."])
    }

    func testPunctuationAttachedToWords() {
        let tokens = WordTokenizer.tokenize("(Hello)! well-known 'quote'")
        XCTAssertEqual(tokens.map(\.text), ["(", "Hello", ")", "!", "well-known", "'", "quote", "'"])
    }

    func testMultipleSpacesAndRangesPointIntoOriginal() {
        let text = "  He   have  cats "
        let tokens = WordTokenizer.tokenize(text)
        XCTAssertEqual(tokens.map(\.text), ["He", "have", "cats"])
        for token in tokens {
            XCTAssertEqual(String(text[token.range]), token.text)
        }
    }

    func testEmpty() {
        XCTAssertTrue(WordTokenizer.tokenize("   ").isEmpty)
    }
}

final class WordDiffTests: XCTestCase {
    func testReplacedWord() {
        let diff = WordDiff(original: "He have two cats.", corrected: "He has two cats.")
        XCTAssertEqual(diff.removedWords, ["have"])
        XCTAssertEqual(diff.insertedWords, ["has"])
        XCTAssertTrue(diff.missingPositions.isEmpty)
        XCTAssertFalse(diff.isIdentical)
    }

    func testMissingWord() {
        let original = "I going home."
        let diff = WordDiff(original: original, corrected: "I am going home.")
        XCTAssertTrue(diff.removedWords.isEmpty)
        XCTAssertEqual(diff.insertedWords, ["am"])
        XCTAssertEqual(diff.missingPositions.count, 1)
        // Vị trí thiếu từ nằm ngay sau "I".
        XCTAssertEqual(original[original.startIndex..<diff.missingPositions[0]], "I")
    }

    func testMissingWordAtStart() {
        let original = "cat is sleeping."
        let diff = WordDiff(original: original, corrected: "The cat is sleeping.")
        XCTAssertEqual(diff.missingPositions, [original.startIndex])
    }

    func testIdenticalIgnoringWhitespace() {
        let diff = WordDiff(original: "I have  finished the report.", corrected: "I have finished the report.")
        XCTAssertTrue(diff.isIdentical)
        XCTAssertEqual(diff.changeRatio, 0)
    }

    func testCapitalizationIsAChange() {
        let diff = WordDiff(original: "i am here.", corrected: "I am here.")
        XCTAssertEqual(diff.removedWords, ["i"])
        XCTAssertEqual(diff.insertedWords, ["I"])
    }

    func testMultipleEdits() {
        let diff = WordDiff(
            original: "He have two cats and they is cute.",
            corrected: "He has two cats and they are cute.")
        XCTAssertEqual(diff.removedWords, ["have", "is"])
        XCTAssertEqual(diff.insertedWords, ["has", "are"])
        XCTAssertEqual(diff.removedTokenCount, 2)
        XCTAssertEqual(diff.originalTokenCount, 9)
    }
}

final class WordFormTests: XCTestCase {
    func testSameWordDifferentForms() {
        XCTAssertTrue(WordDiff.isSameWord("collect", "collecting"))
        XCTAssertTrue(WordDiff.isSameWord("envidences", "evidence"))
        XCTAssertTrue(WordDiff.isSameWord("dont", "doesn't"))
        XCTAssertTrue(WordDiff.isSameWord("has", "have"))
        XCTAssertTrue(WordDiff.isSameWord("go", "went") == false)  // bất quy tắc: khác hẳn về chữ
        XCTAssertTrue(WordDiff.isSameWord("Go", "goes"))
    }

    func testDifferentWords() {
        XCTAssertFalse(WordDiff.isSameWord("gonna", "will"))
        XCTAssertFalse(WordDiff.isSameWord("file", "document"))
        XCTAssertFalse(WordDiff.isSameWord("numbers", "figures"))
    }

    func testDissimilarCount() {
        let fix = WordDiff(original: "I'm collect more envidences", corrected: "I'm collecting more evidence")
        XCTAssertEqual(fix.removedTokenCount, 2)
        XCTAssertEqual(fix.dissimilarRemovedCount, 0)

        let rewrite = WordDiff(
            original: "gonna send u the file tmr, it have the numbers",
            corrected: "I will send you the document tomorrow; it contains the figures.")
        XCTAssertGreaterThan(rewrite.dissimilarChangeRatio, 0.4)
    }
}

final class EditGuardTests: XCTestCase {
    let guardian = EditGuard()

    func testShortSentenceWithSeveralWordFormFixesIsAccepted() {
        XCTAssertEqual(
            guardian.evaluate(WordDiff(original: "I'm collect more envidences", corrected: "I'm collecting more evidence")),
            .accepted)
        XCTAssertEqual(
            guardian.evaluate(WordDiff(original: "She dont has any monies", corrected: "She doesn't have any money")),
            .accepted)
    }

    func testAlmostEverythingChangedIsRejectedEvenIfSimilar() {
        // 5/5 token đổi (dù đều "gần giống"): vượt mức chặn phụ 80%.
        XCTAssertEqual(
            guardian.evaluate(WordDiff(original: "Me want eat many food", corrected: "Mo wants eats more foods")),
            .rewritten)
    }

    func testSingleWordFixIsAccepted() {
        let diff = WordDiff(original: "She go to school yesterday.", corrected: "She went to school yesterday.")
        XCTAssertEqual(guardian.evaluate(diff), .accepted)
    }

    func testIdenticalIsUnchanged() {
        let diff = WordDiff(original: "I have finished the report.", corrected: "I have finished the report.")
        XCTAssertEqual(guardian.evaluate(diff), .unchanged)
    }

    func testFullRewriteIsRejected() {
        let diff = WordDiff(
            original: "gonna send u the file tmr, it have the numbers",
            corrected: "I will send you the document tomorrow; it contains the figures.")
        XCTAssertEqual(guardian.evaluate(diff), .rewritten)
    }

    func testSplittingIntoTwoSentencesIsRejected() {
        let diff = WordDiff(
            original: "I went home and I was tired and I slept early",
            corrected: "I went home and I was tired. I slept early.")
        XCTAssertEqual(guardian.evaluate(diff), .rewritten)
    }

    // MARK: - Đoạn bôi đen

    func testRelaxedAcceptsSingleWordSpellingFix() {
        let diff = WordDiff(original: "recieve", corrected: "receive")
        XCTAssertEqual(guardian.evaluate(diff, relaxed: true), .accepted)
        XCTAssertEqual(guardian.evaluate(diff), .rewritten)
    }

    func testRelaxedStillRejectsDifferentWord() {
        XCTAssertEqual(guardian.evaluate(WordDiff(original: "go", corrected: "went"), relaxed: true), .rewritten)
    }

    func testRelaxedKeepsTotalRatioFromThreeWords() {
        XCTAssertEqual(
            guardian.evaluate(WordDiff(original: "Me want eat many food", corrected: "Mo wants eats more foods"), relaxed: true),
            .rewritten)
    }
}
