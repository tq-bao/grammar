import XCTest
@testable import GrammarKit

final class CaretContextTests: XCTestCase {
    func testConfluenceParagraphWithCaretAtEnd() {
        // Giá trị đọc được từ Chrome khi gõ trong Confluence.
        let paragraph = "I don’t want to mention"
        let (text, cursor) = CaretContext.normalize(paragraph: paragraph, prefix: paragraph)
        XCTAssertEqual(cursor, 23)
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: cursor), "I don’t want to mention")
    }

    func testCaretInsideParagraphPicksThatSentence() {
        let paragraph = "Upgrade React Native from 0.83.1 to 0.87.1. It touches both apps. We bump react too."
        let prefix = "Upgrade React Native from 0.83.1 to 0.87.1. It touc"
        let (text, cursor) = CaretContext.normalize(paragraph: paragraph, prefix: prefix)
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: cursor), "It touches both apps.")
    }

    func testObjectReplacementCharactersAreRemovedKeepingCaretAligned() {
        let paragraph = "Ping \u{FFFC} about it. She go home now."
        let prefix = "Ping \u{FFFC} about it. She go"
        let (text, cursor) = CaretContext.normalize(paragraph: paragraph, prefix: prefix)
        XCTAssertFalse(text.contains("\u{FFFC}"))
        XCTAssertEqual(text, "Ping  about it. She go home now.")
        XCTAssertEqual(cursor, "Ping  about it. She go".utf16.count)
        XCTAssertEqual(SentenceExtractor.sentence(in: text, cursorUTF16Offset: cursor), "She go home now.")
    }

    func testPrefixLongerThanParagraphIsClamped() {
        let (text, cursor) = CaretContext.normalize(paragraph: "Short one", prefix: "Short one and much more text")
        XCTAssertEqual(text, "Short one")
        XCTAssertEqual(cursor, 9)
    }

    func testEmptyPrefixPutsCaretAtStart() {
        let (_, cursor) = CaretContext.normalize(paragraph: "He have two cats. We are fine.", prefix: "")
        XCTAssertEqual(cursor, 0)
    }

    func testEmptyParagraph() {
        let (text, cursor) = CaretContext.normalize(paragraph: "", prefix: "")
        XCTAssertEqual(text, "")
        XCTAssertEqual(cursor, 0)
        XCTAssertNil(SentenceExtractor.sentence(in: text, cursorUTF16Offset: cursor))
    }
}
