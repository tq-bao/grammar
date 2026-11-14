import Foundation

/// Chọn đoạn cần kiểm tra trong ô đang focus: đoạn đang bôi đen nếu có, ngược lại là câu chứa con trỏ.
public enum CheckTarget {
    /// Vùng chọn dài hơn mức này (UTF-16) gần như chắc là ⌘A hoặc bôi đen để copy, không phải để kiểm tra.
    /// Giữ đầu vào và đầu ra vừa context của engine.
    public static let defaultMaxSelectionLength = 1000

    /// - Parameters:
    ///   - text: nội dung ô (hoặc đoạn văn chứa con trỏ) đọc được.
    ///   - cursorUTF16Offset: vị trí con trỏ trong `text`, `nil` nếu không biết.
    ///   - selection: đoạn đang bôi đen, `nil` nếu không có.
    /// - Returns: đoạn cần kiểm tra và nguồn của nó, hoặc `nil` nếu không có gì để kiểm tra.
    public static func resolve(
        text: String,
        cursorUTF16Offset: Int?,
        selection: String?,
        maxSelectionLength: Int = defaultMaxSelectionLength
    ) -> (text: String, source: TextSource)? {
        if let selection {
            let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.utf16.count <= maxSelectionLength {
                return (trimmed, .selection)
            }
        }
        guard let sentence = SentenceExtractor.sentence(in: text, cursorUTF16Offset: cursorUTF16Offset) else { return nil }
        return (sentence, .focusedField)
    }
}
