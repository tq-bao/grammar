import XCTest
@testable import GrammarKit

final class GoldenSetTests: XCTestCase {
    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/golden.json")

    func testParsesAndHasBothKinds() throws {
        let set = try GoldenSet.load(from: Self.url)
        XCTAssertGreaterThanOrEqual(set.incorrect.count, 25)
        XCTAssertGreaterThanOrEqual(set.correct.count, 15)
        XCTAssertGreaterThanOrEqual(set.incorrect.count + set.correct.count, 50)
        for item in set.incorrect {
            XCTAssertFalse(item.expected.isEmpty, item.input)
            XCTAssertFalse(item.expected.contains(item.input), "Câu sai không được có đáp án trùng câu gốc: \(item.input)")
        }
    }

    func testReportMetrics() {
        var report = EvaluationReport()
        report.items = [
            .init(input: "They was happy.", output: "They were happy.", expected: ["They were happy."], verdict: .accepted, seconds: 0.2),
            .init(input: "He go.", output: "He go.", expected: ["He goes."], verdict: .unchanged, seconds: 0.4),
            .init(input: "I am fine.", output: "I am fine.", expected: nil, verdict: .unchanged, seconds: 0.1),
            .init(input: "I am ok.", output: "I'm doing okay today.", expected: nil, verdict: .rewritten, seconds: 0.3),
        ]
        XCTAssertEqual(report.matchRate, 0.5)
        XCTAssertEqual(report.keepRate, 0.5)
        XCTAssertEqual(report.rewriteRate, 0.25)
        XCTAssertEqual(report.p50, 0.2)
        XCTAssertEqual(report.p95, 0.4)
    }
}
