import Foundation

/// Đối chiếu câu sửa với câu gốc để bỏ qua những thứ người dùng không muốn kiểm tra:
/// - viết hoa/viết thường: từ chỉ khác hoa thường thì lấy lại đúng chữ của câu gốc;
/// - dấu câu cuối câu: bỏ dấu cuối của câu sửa và gắn lại dấu cuối của câu gốc.
public enum CorrectionNormalizer {
    /// Dấu câu ở cuối câu được bỏ qua khi kiểm tra.
    public static let finalPunctuation: Set<String> = [".", ",", ";", ":", "!", "?", "…"]

    public static func reconcile(original: String, corrected: String) -> String {
        let a = WordTokenizer.tokenize(original)
        let b = WordTokenizer.tokenize(corrected)
        let aEnd = coreEnd(a)
        let bEnd = coreEnd(b)
        // Một trong hai câu chỉ toàn dấu câu: không có gì để sửa.
        guard aEnd > 0, bEnd > 0 else { return original.trimmingCharacters(in: .whitespacesAndNewlines) }

        // So khớp phần thân câu, không phân biệt hoa thường.
        let aWords = a[..<aEnd].map { $0.text.lowercased() }
        let bWords = b[..<bEnd].map { $0.text.lowercased() }
        let matches = matchedPairs(from: aWords, to: bWords)

        // Dựng lại thân câu sửa: giữ khoảng trắng của câu sửa, từ khớp lấy chữ của câu gốc.
        var result = ""
        var cursor = b[0].range.lowerBound
        for j in 0..<bEnd {
            result += corrected[cursor..<b[j].range.lowerBound]
            result += matches[j].map { a[$0].text } ?? b[j].text
            cursor = b[j].range.upperBound
        }

        // Gắn lại phần đuôi của câu gốc (dấu câu cuối, nếu có), bỏ khoảng trắng thừa ở cuối.
        var tail = Substring(original[a[aEnd - 1].range.upperBound...])
        while let last = tail.last, last.isWhitespace { tail = tail.dropLast() }
        return result + tail
    }

    /// Vị trí ngay sau token cuối cùng không phải dấu câu cuối câu.
    private static func coreEnd(_ tokens: [TextToken]) -> Int {
        var end = tokens.count
        while end > 0, finalPunctuation.contains(tokens[end - 1].text) { end -= 1 }
        return end
    }

    /// Với mỗi token của `b`, chỉ số token tương ứng trong `a` nếu hai token khớp (nil nếu là từ mới hoặc bị thay).
    private static func matchedPairs(from a: [String], to b: [String]) -> [Int?] {
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in b.difference(from: a) {
            switch change {
            case let .remove(offset, _, _): removed.insert(offset)
            case let .insert(offset, _, _): inserted.insert(offset)
            }
        }
        var result = [Int?](repeating: nil, count: b.count)
        var i = 0
        var j = 0
        while i < a.count || j < b.count {
            if i < a.count, removed.contains(i) {
                i += 1
            } else if j < b.count, inserted.contains(j) {
                j += 1
            } else {
                if j < b.count, i < a.count { result[j] = i }
                i += 1
                j += 1
            }
        }
        return result
    }
}
