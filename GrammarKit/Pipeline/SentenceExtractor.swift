import Foundation
import NaturalLanguage

/// Lấy ra câu đang chứa con trỏ trong nội dung một ô nhập liệu.
public enum SentenceExtractor {
    /// - Parameters:
    ///   - text: toàn bộ nội dung ô nhập liệu.
    ///   - cursorUTF16Offset: vị trí con trỏ tính theo UTF-16 (đơn vị Accessibility API dùng).
    ///     `nil` khi app không cung cấp. Khi đó lấy câu cuối cùng.
    /// - Returns: câu đã bỏ khoảng trắng hai đầu, hoặc `nil` nếu ô trống.
    public static func sentence(in text: String, cursorUTF16Offset: Int?) -> String? {
        let ranges = sentenceRanges(in: text)
        guard !ranges.isEmpty else { return nil }

        guard let offset = cursorUTF16Offset else {
            return trimmed(text[ranges[ranges.count - 1]])
        }

        let clamped = min(max(offset, 0), text.utf16.count)
        let cursor = String.Index(utf16Offset: clamped, in: text)

        // Ưu tiên câu có con trỏ nằm hẳn bên trong. Con trỏ ở ngay cuối text thì thuộc câu cuối.
        if let inside = ranges.first(where: { $0.lowerBound <= cursor && cursor < $0.upperBound }) {
            return trimmed(text[inside])
        }
        if let before = ranges.last(where: { $0.lowerBound <= cursor }) {
            return trimmed(text[before])
        }
        return trimmed(text[ranges[0]])
    }

    static func sentenceRanges(in text: String) -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var ranges: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if !text[range].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ranges.append(range)
            }
            return true
        }
        return ranges
    }

    private static func trimmed(_ s: Substring) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
