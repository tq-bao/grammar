import Foundation
import NaturalLanguage

/// Quyết định một câu có được đưa đi kiểm tra ngữ pháp hay không.
public struct LanguageGate: Sendable {
    public enum Verdict: Equatable, Sendable {
        case english
        case notEnglish
        case tooShort
    }

    public var minimumWords: Int
    /// Khả năng là tiếng Anh tối thiểu. 0.5 nghĩa là tiếng Anh phải là khả năng cao nhất.
    public var minimumConfidence: Double

    /// Người dùng chủ yếu gõ tiếng Anh và tiếng Việt. Báo trước cho bộ nhận diện để câu tiếng Anh ngắn
    /// có tên riêng tiếng Việt ("Hi, my name is Bao") không bị nhận nhầm là ngôn ngữ khác.
    public static let languageHints: [NLLanguage: Double] = [.english: 0.6, .vietnamese: 0.4]

    public init(minimumWords: Int = 3, minimumConfidence: Double = 0.5) {
        self.minimumWords = minimumWords
        self.minimumConfidence = minimumConfidence
    }

    public func evaluate(_ sentence: String) -> Verdict {
        let words = WordTokenizer.tokenize(sentence).filter { $0.text.contains(where: \.isLetter) }
        guard words.count >= minimumWords else { return .tooShort }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageHints = Self.languageHints
        recognizer.processString(sentence)
        let confidence = recognizer.languageHypotheses(withMaximum: 3)[.english] ?? 0
        return confidence >= minimumConfidence ? .english : .notEnglish
    }
}
