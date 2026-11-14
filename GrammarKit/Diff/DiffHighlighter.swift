import Foundation
import SwiftUI

/// Các vùng cần đánh dấu khi hiển thị một `WordDiff`, tính theo `NSRange` (UTF-16).
public struct DiffHighlights: Equatable, Sendable {
    /// Vùng trong câu gốc bị sai (xoá hoặc thay) -> gạch chân đỏ.
    public let underlines: [NSRange]
    /// Chỗ thiếu từ trong câu gốc -> dấu đỏ ở khoảng trống.
    public let gaps: [NSRange]
    /// Vùng trong câu sửa được thêm hoặc thay -> tô xanh, in đậm.
    public let insertions: [NSRange]
}

public enum DiffHighlighter {
    public static let errorColor = Color.red
    public static let fixColor = Color.green

    public static func highlights(for diff: WordDiff) -> DiffHighlights {
        let original = diff.original
        let corrected = diff.corrected
        return DiffHighlights(
            underlines: diff.removedRanges.map { NSRange($0, in: original) },
            gaps: diff.missingPositions.compactMap { gapRange(in: original, at: $0) }.map { NSRange($0, in: original) },
            insertions: diff.insertedRanges.map { NSRange($0, in: corrected) })
    }

    /// Ký tự dùng để đánh dấu chỗ thiếu từ: khoảng trắng tại vị trí đó nếu có,
    /// nếu không thì ký tự kề bên.
    static func gapRange(in text: String, at position: String.Index) -> Range<String.Index>? {
        guard !text.isEmpty else { return nil }
        if position < text.endIndex {
            return position..<text.index(after: position)
        }
        return text.index(before: text.endIndex)..<text.endIndex
    }

    // MARK: - AttributedString cho SwiftUI `Text`

    /// Câu gốc: gạch chân đỏ cụm sai, nền đỏ nhạt + gạch chân ở chỗ thiếu từ.
    public static func originalText(_ diff: WordDiff) -> AttributedString {
        let original = diff.original
        var result = AttributedString(original)
        let underline = Text.LineStyle(pattern: .solid, color: errorColor)

        for range in diff.removedRanges {
            guard let r = Range(range, in: result) else { continue }
            result[r].swiftUI.underlineStyle = underline
        }
        for position in diff.missingPositions {
            guard let gap = gapRange(in: original, at: position), let r = Range(gap, in: result) else { continue }
            result[r].swiftUI.underlineStyle = underline
            result[r].swiftUI.backgroundColor = errorColor.opacity(0.3)
        }
        return result
    }

    /// Câu sửa: tô xanh và in đậm phần được thêm/thay.
    public static func correctedText(_ diff: WordDiff) -> AttributedString {
        var result = AttributedString(diff.corrected)
        for range in diff.insertedRanges {
            guard let r = Range(range, in: result) else { continue }
            result[r].swiftUI.foregroundColor = fixColor
            result[r].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}
