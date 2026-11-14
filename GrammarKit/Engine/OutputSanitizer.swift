import Foundation

/// Làm sạch output của LLM: bỏ tiền tố, ngoặc kép bao ngoài, chỉ lấy dòng đầu.
public enum OutputSanitizer {
    private static let prefixes = [
        "corrected text:", "corrected sentence:", "corrected:", "correction:",
        "text:", "output:", "answer:",
    ]

    private static let quotePairs: [(Character, Character)] = [
        ("\"", "\""), ("“", "”"), ("'", "'"), ("‘", "’"), ("`", "`"),
    ]

    /// - Parameters:
    ///   - output: text thô mô hình sinh ra.
    ///   - original: câu gốc. Dùng để giữ ngoặc kép nếu câu gốc vốn có, và làm giá trị dự phòng khi output rỗng.
    public static func clean(_ output: String, original: String) -> String {
        let firstLine = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""

        var text = firstLine

        // Bỏ tiền tố kiểu "Corrected:" (lặp vì có thể có "Corrected text: Text: ...").
        var stripped = true
        while stripped {
            stripped = false
            let lower = text.lowercased()
            for prefix in prefixes where lower.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                stripped = true
                break
            }
        }

        // Bỏ ngoặc kép bao ngoài, trừ khi câu gốc cũng được bao như vậy.
        let trimmedOriginal = original.trimmingCharacters(in: .whitespaces)
        for (open, close) in quotePairs {
            if text.count >= 2, text.first == open, text.last == close,
               !(trimmedOriginal.first == open && trimmedOriginal.last == close) {
                text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        return text.isEmpty ? trimmedOriginal : text
    }
}
