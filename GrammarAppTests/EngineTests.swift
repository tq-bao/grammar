import XCTest
@testable import GrammarKit

final class OutputSanitizerTests: XCTestCase {
    func testStripsPrefixAndQuotes() {
        XCTAssertEqual(
            OutputSanitizer.clean("Corrected: \"They were happy.\"", original: "They was happy."),
            "They were happy.")
    }

    func testTakesFirstNonEmptyLine() {
        XCTAssertEqual(
            OutputSanitizer.clean("\n  He has two cats.\nExplanation: 'have' -> 'has'", original: "He have two cats."),
            "He has two cats.")
    }

    func testStripsSmartQuotesAndStackedPrefixes() {
        XCTAssertEqual(
            OutputSanitizer.clean("Corrected text: Text: “I am here.”", original: "i am here."),
            "I am here.")
    }

    func testKeepsQuotesWhenOriginalHasThem() {
        XCTAssertEqual(
            OutputSanitizer.clean("\"Stop,\" he said.\"", original: "\"Stop,\" he say.\""),
            "\"Stop,\" he said.\"")
    }

    func testEmptyOutputFallsBackToOriginal() {
        XCTAssertEqual(OutputSanitizer.clean("   \n ", original: "I am fine."), "I am fine.")
    }
}

final class GrammarPromptTests: XCTestCase {
    func testMessagesEndWithUserSentence() {
        let messages = GrammarPrompt.messages(for: "They was happy.")
        XCTAssertEqual(messages.first?.role, .system)
        XCTAssertEqual(messages.last, .init(role: .user, content: "Text: They was happy."))
        XCTAssertEqual(messages.count, 2 + GrammarPrompt.examples.count * 2)
    }
}

/// Test với model thật. Bỏ qua khi chưa tải model.
/// Đặt GRAMMAR_MODEL_PATH hoặc để model ở GrammarApp/Resources/Models/.
final class LlamaEngineIntegrationTests: XCTestCase {
    static func modelURL() -> URL? {
        if let path = ProcessInfo.processInfo.environment[ModelLocator.environmentKey] {
            return URL(fileURLWithPath: path)
        }
        let repoModels = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("GrammarApp/Resources/Models")
            .appendingPathComponent(ModelLocator.defaultModelFileName)
        return FileManager.default.fileExists(atPath: repoModels.path) ? repoModels : nil
    }

    func testCorrectsSubjectVerbAgreementOffline() async throws {
        guard let url = Self.modelURL() else {
            throw XCTSkip("Chưa có model, chạy scripts/download-model.sh trước.")
        }
        let engine = try LlamaGrammarEngine(modelURL: url)
        let result = try await engine.correct("They was happy.")
        XCTAssertEqual(result, "They were happy.")
    }

    func testCorrectSentenceIsUnchanged() async throws {
        guard let url = Self.modelURL() else {
            throw XCTSkip("Chưa có model, chạy scripts/download-model.sh trước.")
        }
        let engine = try LlamaGrammarEngine(modelURL: url)
        let result = try await engine.correct("I have finished the report.")
        XCTAssertEqual(result, "I have finished the report.")
    }

    func testMissingModelFileThrowsClearError() {
        XCTAssertThrowsError(try LlamaGrammarEngine(modelURL: URL(fileURLWithPath: "/nonexistent/model.gguf"))) { error in
            XCTAssertEqual(error as? GrammarEngineError, .modelLoadFailed("/nonexistent/model.gguf"))
        }
    }

    func testLocatorReportsMissingModel() {
        XCTAssertThrowsError(try ModelLocator.locate(fileName: "nope.gguf", bundle: Bundle(for: Self.self), environment: [:])) { error in
            XCTAssertEqual(error as? GrammarEngineError, .modelNotFound("nope.gguf"))
        }
    }
}
