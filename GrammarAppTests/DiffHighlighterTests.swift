import SwiftUI
import XCTest
@testable import GrammarKit

final class DiffHighlighterTests: XCTestCase {
    typealias UnderlineKey = AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute
    typealias ForegroundKey = AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute
    typealias BackgroundKey = AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute

    /// Các đoạn text có attribute `K` khác nil.
    private func segments<K: AttributedStringKey>(_ s: AttributedString, with key: K.Type) -> [String]
    where K.Value: Sendable {
        s.runs.compactMap { run in
            run[K.self] == nil ? nil : String(s[run.range].characters)
        }
    }

    func testReplacedWordIsUnderlinedAndFixIsHighlighted() {
        let diff = WordDiff(original: "He have two cats.", corrected: "He has two cats.")
        let h = DiffHighlighter.highlights(for: diff)
        XCTAssertEqual(h.underlines, [NSRange(location: 3, length: 4)])  // "have"
        XCTAssertEqual(h.insertions, [NSRange(location: 3, length: 3)])  // "has"
        XCTAssertTrue(h.gaps.isEmpty)
    }

    func testMissingWordMarksTheGapBetweenWords() {
        let diff = WordDiff(original: "I going home.", corrected: "I am going home.")
        let h = DiffHighlighter.highlights(for: diff)
        XCTAssertTrue(h.underlines.isEmpty)
        XCTAssertEqual(h.gaps, [NSRange(location: 1, length: 1)])  // khoảng trắng giữa "I" và "going"
    }

    func testOriginalTextUnderlinesWrongWordInRed() {
        let diff = WordDiff(original: "He have two cats.", corrected: "He has two cats.")
        let s = DiffHighlighter.originalText(diff)
        XCTAssertEqual(String(s.characters), "He have two cats.")
        XCTAssertEqual(segments(s, with: UnderlineKey.self), ["have"])
        let style = s.runs.compactMap { $0[UnderlineKey.self] }.first
        XCTAssertEqual(style, Text.LineStyle(pattern: .solid, color: .red))
    }

    func testOriginalTextMarksMissingWordGap() {
        let diff = WordDiff(original: "I going home.", corrected: "I am going home.")
        let s = DiffHighlighter.originalText(diff)
        XCTAssertEqual(segments(s, with: BackgroundKey.self), [" "])
        XCTAssertEqual(segments(s, with: UnderlineKey.self), [" "])
    }

    func testCorrectedTextHighlightsInsertedWordsInGreenBold() {
        let diff = WordDiff(original: "He have two cats.", corrected: "He has two cats.")
        let s = DiffHighlighter.correctedText(diff)
        XCTAssertEqual(String(s.characters), "He has two cats.")
        XCTAssertEqual(segments(s, with: ForegroundKey.self), ["has"])
        let bold = s.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
            .map { String(s[$0.range].characters) }
        XCTAssertEqual(bold, ["has"])
    }

    func testIdenticalSentenceHasNoHighlights() {
        let diff = WordDiff(original: "I am fine.", corrected: "I am fine.")
        XCTAssertTrue(segments(DiffHighlighter.originalText(diff), with: UnderlineKey.self).isEmpty)
        XCTAssertTrue(segments(DiffHighlighter.correctedText(diff), with: ForegroundKey.self).isEmpty)
    }
}
