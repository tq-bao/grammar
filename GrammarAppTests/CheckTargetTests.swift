import XCTest
@testable import GrammarKit

final class CheckTargetTests: XCTestCase {
    let text = "I like tea. He have two cats. We is fine."
    var cursorInSecond: Int {
        text.utf16.distance(from: text.startIndex, to: text.range(of: "two")!.lowerBound)
    }

    private func resolve(_ selection: String?, max: Int = CheckTarget.defaultMaxSelectionLength) -> (String, TextSource)? {
        CheckTarget.resolve(text: text, cursorUTF16Offset: cursorInSecond, selection: selection, maxSelectionLength: max)
            .map { ($0.text, $0.source) }
    }

    func testSelectionWins() {
        let r = resolve(" recieve\n")
        XCTAssertEqual(r?.0, "recieve")
        XCTAssertEqual(r?.1, .selection)
    }

    func testNoSelectionUsesSentenceAtCursor() {
        for selection in [nil, "", " \n"] as [String?] {
            let r = resolve(selection)
            XCTAssertEqual(r?.0, "He have two cats.", "selection = \(String(describing: selection))")
            XCTAssertEqual(r?.1, .focusedField)
        }
    }

    func testTooLongSelectionUsesSentenceAtCursor() {
        let r = resolve(String(repeating: "a", count: 1001))
        XCTAssertEqual(r?.0, "He have two cats.")
        XCTAssertEqual(r?.1, .focusedField)
    }

    func testSelectionAtLimitIsKept() {
        let selection = String(repeating: "a", count: 1000)
        let r = resolve(selection)
        XCTAssertEqual(r?.0, selection)
        XCTAssertEqual(r?.1, .selection)
    }

    func testLimitCountsUTF16() {
        // Mỗi emoji là 2 đơn vị UTF-16: 501 emoji = 1002 > 1000.
        let r = resolve(String(repeating: "😀", count: 501))
        XCTAssertEqual(r?.1, .focusedField)
    }

    func testMultiSentenceSelectionIsKeptWhole() {
        let r = resolve("He have two cats. We is fine.")
        XCTAssertEqual(r?.0, "He have two cats. We is fine.")
        XCTAssertEqual(r?.1, .selection)
    }

    func testEmptyTextWithoutSelectionIsNil() {
        XCTAssertNil(CheckTarget.resolve(text: "  ", cursorUTF16Offset: 0, selection: nil))
    }
}
