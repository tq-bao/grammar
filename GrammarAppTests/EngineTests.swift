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

final class TranslationSanitizerTests: XCTestCase {
    func testStripsPrefixes() throws {
        XCTAssertEqual(try OutputSanitizer.cleanTranslation("Translation: Anh ấy có hai con mèo."), "Anh ấy có hai con mèo.")
        XCTAssertEqual(try OutputSanitizer.cleanTranslation("Bản dịch: Tôi đã xong báo cáo."), "Tôi đã xong báo cáo.")
        XCTAssertEqual(try OutputSanitizer.cleanTranslation("Vietnamese translation: Xin chào."), "Xin chào.")
    }

    func testStripsSurroundingQuotes() throws {
        XCTAssertEqual(try OutputSanitizer.cleanTranslation("“Anh ấy có hai con mèo.”"), "Anh ấy có hai con mèo.")
        XCTAssertEqual(try OutputSanitizer.cleanTranslation("\"Xin chào.\""), "Xin chào.")
    }

    func testTakesFirstNonEmptyLine() throws {
        XCTAssertEqual(
            try OutputSanitizer.cleanTranslation("\n  Hôm qua cô ấy đã đi học.\n(Note: past tense)"),
            "Hôm qua cô ấy đã đi học.")
    }

    func testEmptyOutputThrows() {
        for output in ["", "   \n  ", "Translation:", "\"\""] {
            XCTAssertThrowsError(try OutputSanitizer.cleanTranslation(output), output) { error in
                XCTAssertEqual(error as? GrammarEngineError, .emptyTranslation)
            }
        }
    }
}

final class CJKFilterTests: XCTestCase {
    func testDetectsChineseJapaneseKorean() {
        for text in ["练习", "翻译", "ひらがな", "カタカナ", "한국어", "，"] {
            XCTAssertTrue(text.unicodeScalars.contains(where: LlamaGrammarEngine.isCJK), text)
        }
    }

    func testVietnameseAndLatinAreAllowed() {
        for text in ["Tôi giỏi môn toán", "Đường phố", "ửữựỳýỷỹỵđ", "Kubernetes 3 PM", "file, nhé!"] {
            XCTAssertFalse(text.unicodeScalars.contains(where: LlamaGrammarEngine.isCJK), text)
        }
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

final class TranslationPromptTests: XCTestCase {
    func testMessagesEndWithSentenceToTranslate() {
        let messages = TranslationPrompt.messages(for: "He has two cats.")
        XCTAssertEqual(messages.first?.role, .system)
        XCTAssertEqual(messages.last, .init(role: .user, content: "English: He has two cats."))
        XCTAssertEqual(messages.count, 1 + TranslationPrompt.examples.count * 2 + 1)
    }

    func testExamplesAlternateUserAndAssistant() {
        let messages = TranslationPrompt.messages(for: "x")
        for (index, message) in messages.dropFirst().dropLast().enumerated() {
            XCTAssertEqual(message.role, index.isMultiple(of: 2) ? .user : .assistant)
        }
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

    func testTranslatesToVietnameseWithoutBreakingCorrection() async throws {
        guard let url = Self.modelURL() else {
            throw XCTSkip("Chưa có model, chạy scripts/download-model.sh trước.")
        }
        let engine = try LlamaGrammarEngine(modelURL: url)
        let translation = try await engine.translate("I have finished the report.")
        XCTAssertFalse(translation.isEmpty)
        // Có ít nhất một chữ tiếng Việt có dấu.
        let vietnamese = CharacterSet(charactersIn: "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ")
        XCTAssertNotNil(translation.lowercased().rangeOfCharacter(from: vietnamese), translation)

        // Bước sửa vẫn đúng sau khi dịch (context riêng, prefix cache không bị xoá).
        let corrected = try await engine.correct("He have two cats.")
        XCTAssertEqual(corrected, "He has two cats.")
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

/// Thứ tự tìm model: biến môi trường → Application Support → bundle.
final class ModelLocatorTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ModelLocatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Tạo một bundle giả có `Resources/Models/<file>`.
    private func makeBundle(withModel fileName: String?) throws -> Bundle {
        let bundleURL = root.appendingPathComponent("Fake.bundle")
        let models = bundleURL.appendingPathComponent("Contents/Resources/Models")
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        if let fileName {
            try Data("GGUF".utf8).write(to: models.appendingPathComponent(fileName))
        }
        return try XCTUnwrap(Bundle(url: bundleURL))
    }

    private func makeAppSupport(withModel fileName: String?) throws -> URL {
        let dir = root.appendingPathComponent("AppSupport/Grammar/Models")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let fileName {
            try Data("GGUF".utf8).write(to: dir.appendingPathComponent(fileName))
        }
        return dir
    }

    func testApplicationSupportWinsOverBundle() throws {
        let bundle = try makeBundle(withModel: "m.gguf")
        let appSupport = try makeAppSupport(withModel: "m.gguf")
        let url = try ModelLocator.locate(fileName: "m.gguf", bundle: bundle, environment: [:], applicationSupportDirectory: appSupport)
        XCTAssertEqual(url.standardizedFileURL, appSupport.appendingPathComponent("m.gguf").standardizedFileURL)
    }

    func testFallsBackToBundle() throws {
        let bundle = try makeBundle(withModel: "m.gguf")
        let appSupport = try makeAppSupport(withModel: nil)
        let url = try ModelLocator.locate(fileName: "m.gguf", bundle: bundle, environment: [:], applicationSupportDirectory: appSupport)
        XCTAssertTrue(url.path.hasSuffix("Contents/Resources/Models/m.gguf"), url.path)
    }

    func testEnvironmentWinsOverEverything() throws {
        let bundle = try makeBundle(withModel: "m.gguf")
        let appSupport = try makeAppSupport(withModel: "m.gguf")
        let custom = root.appendingPathComponent("custom.gguf")
        try Data("GGUF".utf8).write(to: custom)
        let url = try ModelLocator.locate(
            fileName: "m.gguf", bundle: bundle,
            environment: [ModelLocator.environmentKey: custom.path],
            applicationSupportDirectory: appSupport
        )
        XCTAssertEqual(url.path, custom.path)
    }

    func testNotFoundAnywhereThrows() throws {
        let bundle = try makeBundle(withModel: nil)
        let appSupport = try makeAppSupport(withModel: nil)
        XCTAssertThrowsError(try ModelLocator.locate(fileName: "m.gguf", bundle: bundle, environment: [:], applicationSupportDirectory: appSupport)) { error in
            XCTAssertEqual(error as? GrammarEngineError, .modelNotFound("m.gguf"))
        }
    }

    func testDownloadDestinationIsInsideModelsDirectory() throws {
        let appSupport = try makeAppSupport(withModel: nil)
        XCTAssertEqual(
            ModelLocator.downloadDestination(modelsDirectory: appSupport),
            appSupport.appendingPathComponent(ModelLocator.defaultModelFileName)
        )
        XCTAssertTrue(ModelLocator.applicationSupportModelsDirectory()?.path.hasSuffix("Application Support/Grammar/Models") ?? false)
    }
}
