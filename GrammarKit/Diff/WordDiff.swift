import Foundation

/// Kết quả so sánh câu gốc với câu đã sửa theo từng token.
///
/// Dùng cho cả hiển thị (gạch chân đỏ ở câu gốc, tô nổi bật ở câu sửa)
/// lẫn `EditGuard` (đo mức độ thay đổi).
public struct WordDiff: Equatable, Sendable {
    public let original: String
    public let corrected: String

    /// Vùng trong `original` bị xoá hoặc bị thay (cần gạch chân đỏ).
    public let removedRanges: [Range<String.Index>]
    /// Vùng trong `corrected` được thêm vào hoặc thay đổi (cần tô nổi bật).
    public let insertedRanges: [Range<String.Index>]
    /// Vị trí trong `original` bị thiếu từ: câu sửa chèn thêm từ mà không xoá gì ở đó.
    public let missingPositions: [String.Index]

    public let originalTokenCount: Int
    public let removedTokenCount: Int
    /// Số token gốc bị thay bằng một từ khác hẳn (không tính sửa dạng từ/chính tả, không tính dấu câu).
    public let dissimilarRemovedCount: Int

    /// Hai câu giống nhau (bỏ qua khác biệt về khoảng trắng).
    public var isIdentical: Bool {
        removedRanges.isEmpty && insertedRanges.isEmpty
    }

    /// Tỉ lệ token gốc bị xoá/thay, từ 0 đến 1.
    public var changeRatio: Double {
        guard originalTokenCount > 0 else { return insertedRanges.isEmpty ? 0 : 1 }
        return Double(removedTokenCount) / Double(originalTokenCount)
    }

    /// Tỉ lệ token gốc bị thay bằng một từ khác hẳn, từ 0 đến 1.
    public var dissimilarChangeRatio: Double {
        guard originalTokenCount > 0 else { return insertedRanges.isEmpty ? 0 : 1 }
        return Double(dissimilarRemovedCount) / Double(originalTokenCount)
    }

    public init(original: String, corrected: String) {
        self.original = original
        self.corrected = corrected

        let a = WordTokenizer.tokenize(original)
        let b = WordTokenizer.tokenize(corrected)
        // So sánh phân biệt hoa thường để lỗi viết hoa ("i am" -> "I am") cũng được đánh dấu.
        let diff = b.map(\.text).difference(from: a.map(\.text))

        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in diff {
            switch change {
            case let .remove(offset, _, _): removed.insert(offset)
            case let .insert(offset, _, _): inserted.insert(offset)
            }
        }

        var removedRanges: [Range<String.Index>] = []
        var insertedRanges: [Range<String.Index>] = []
        var missing: [String.Index] = []

        // Duyệt song song hai dãy token để gom các nhóm thay đổi nằm giữa hai token giữ nguyên.
        var i = 0
        var j = 0
        var groupHasRemoval = false
        var groupHasInsertion = false
        var groupRemoved: [String] = []
        var groupInserted: [String] = []
        var dissimilar = 0

        func flushGroup(atOriginalIndex i: Int) {
            dissimilar += Self.unmatchedCount(removed: groupRemoved, inserted: groupInserted)
            groupRemoved = []
            groupInserted = []
            if groupHasInsertion && !groupHasRemoval, !a.isEmpty {
                // Chèn thêm từ mà không xoá gì: đánh dấu vị trí ngay sau token đứng trước.
                let position = i > 0 ? a[i - 1].range.upperBound : a[0].range.lowerBound
                missing.append(position)
            }
            groupHasRemoval = false
            groupHasInsertion = false
        }

        while i < a.count || j < b.count {
            if i < a.count, removed.contains(i) {
                removedRanges.append(a[i].range)
                groupRemoved.append(a[i].text)
                groupHasRemoval = true
                i += 1
            } else if j < b.count, inserted.contains(j) {
                insertedRanges.append(b[j].range)
                groupInserted.append(b[j].text)
                groupHasInsertion = true
                j += 1
            } else {
                flushGroup(atOriginalIndex: i)
                i += 1
                j += 1
            }
        }
        flushGroup(atOriginalIndex: i)

        self.removedRanges = removedRanges
        self.insertedRanges = insertedRanges
        self.missingPositions = missing
        self.originalTokenCount = a.count
        self.removedTokenCount = removed.count
        self.dissimilarRemovedCount = dissimilar
    }

    // MARK: - Sửa dạng từ / chính tả

    /// Số từ bị xoá trong một nhóm thay đổi mà không ghép được với từ thêm vào nào "gần giống".
    static func unmatchedCount(removed: [String], inserted: [String]) -> Int {
        var available = inserted
        var unmatched = 0
        for word in removed {
            if isPunctuation(word) { continue }  // thay/xoá dấu câu không tính là viết lại
            if let index = available.firstIndex(where: { isSameWord(word, $0) }) {
                available.remove(at: index)
            } else {
                unmatched += 1
            }
        }
        return unmatched
    }

    /// Hai từ được coi là cùng một từ (chỉ khác dạng hoặc chính tả):
    /// là tiền tố của nhau (tối thiểu 3 ký tự), hoặc khoảng cách Levenshtein ≤ 50% độ dài từ dài hơn.
    static func isSameWord(_ a: String, _ b: String) -> Bool {
        let x = Array(a.lowercased())
        let y = Array(b.lowercased())
        guard !x.isEmpty, !y.isEmpty else { return false }
        if min(x.count, y.count) >= 3, x.starts(with: y) || y.starts(with: x) { return true }
        return Double(levenshtein(x, y)) <= 0.5 * Double(max(x.count, y.count))
    }

    static func isPunctuation(_ token: String) -> Bool {
        !token.contains { $0.isLetter || $0.isNumber }
    }

    static func levenshtein(_ x: [Character], _ y: [Character]) -> Int {
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[y.count]
    }

    /// Các đoạn text bị gạch chân trong câu gốc (tiện cho test và debug).
    public var removedWords: [String] { removedRanges.map { String(original[$0]) } }
    /// Các đoạn text được tô nổi bật trong câu sửa.
    public var insertedWords: [String] { insertedRanges.map { String(corrected[$0]) } }
}
