import Foundation
import NaturalLanguage

/// Chặn những kết quả mà mô hình "viết lại câu" thay vì chỉ sửa ngữ pháp.
public struct EditGuard: Sendable {
    public enum Verdict: Equatable, Sendable {
        case unchanged
        case accepted
        case rewritten
    }

    /// Tỉ lệ token gốc bị thay bằng từ khác hẳn tối đa được chấp nhận.
    /// Sửa dạng từ/chính tả (collect → collecting) không tính.
    public var maxChangeRatio: Double
    /// Tỉ lệ tổng số token thay đổi tối đa (kể cả sửa dạng từ), chặn trường hợp gần như cả câu bị đổi.
    public var maxTotalChangeRatio: Double

    public init(maxChangeRatio: Double = 0.4, maxTotalChangeRatio: Double = 0.8) {
        self.maxChangeRatio = maxChangeRatio
        self.maxTotalChangeRatio = maxTotalChangeRatio
    }

    public func evaluate(_ diff: WordDiff) -> Verdict {
        if diff.isIdentical { return .unchanged }
        if diff.dissimilarChangeRatio > maxChangeRatio { return .rewritten }
        if diff.changeRatio > maxTotalChangeRatio { return .rewritten }
        // Mô hình tách thành nhiều câu hơn câu gốc -> đang diễn đạt lại.
        if Self.sentenceCount(diff.corrected) > max(1, Self.sentenceCount(diff.original)) {
            return .rewritten
        }
        return .accepted
    }

    static func sentenceCount(_ text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if !text[range].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
            return true
        }
        return count
    }
}
