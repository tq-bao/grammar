import Foundation

/// Chuẩn hoá đoạn văn chứa con trỏ đọc được qua Accessibility text marker.
///
/// Trình soạn thảo web (Chrome, Safari, Electron) trả về đoạn văn và phần từ đầu đoạn tới con trỏ
/// dưới dạng hai chuỗi riêng. Vị trí con trỏ là độ dài phần đầu đoạn (UTF-16), cùng hệ với `SentenceExtractor`.
public enum CaretContext {
    /// Ký tự thay thế cho phần tử nhúng (ảnh, mention, emoji tuỳ biến…).
    static let objectReplacement: Character = "\u{FFFC}"

    /// - Parameters:
    ///   - paragraph: đoạn văn chứa con trỏ.
    ///   - prefix: phần từ đầu đoạn tới con trỏ.
    /// - Returns: đoạn văn đã bỏ ký tự phần tử nhúng, và vị trí con trỏ (UTF-16) trong đoạn đó.
    public static func normalize(paragraph: String, prefix: String) -> (text: String, cursor: Int) {
        let text = paragraph.filter { $0 != objectReplacement }
        let head = prefix.filter { $0 != objectReplacement }
        let cursor = min(head.utf16.count, text.utf16.count)
        return (text, cursor)
    }
}
