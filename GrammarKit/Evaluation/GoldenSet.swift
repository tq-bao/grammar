import Foundation

/// Bộ câu đánh giá model (GrammarAppTests/Fixtures/golden.json).
public struct GoldenSet: Decodable, Sendable {
    public struct Incorrect: Decodable, Sendable {
        public let category: String
        public let input: String
        /// Các đáp án được chấp nhận.
        public let expected: [String]
    }

    public let incorrect: [Incorrect]
    /// Câu đúng: model phải trả về nguyên văn.
    public let correct: [String]

    public static func load(from url: URL) throws -> GoldenSet {
        try JSONDecoder().decode(GoldenSet.self, from: Data(contentsOf: url))
    }
}

/// Kết quả chấm một model trên golden set.
public struct EvaluationReport: Sendable {
    public struct Item: Sendable {
        public let input: String
        public let output: String
        public let expected: [String]?  // nil = câu đúng, phải giữ nguyên
        public let verdict: EditGuard.Verdict
        public let seconds: Double

        public init(input: String, output: String, expected: [String]?, verdict: EditGuard.Verdict, seconds: Double) {
            self.input = input
            self.output = output
            self.expected = expected
            self.verdict = verdict
            self.seconds = seconds
        }

        public var passed: Bool {
            let out = ResultCache<Int>.normalize(output)
            if let expected {
                // Đáp án cũng được đối chiếu với câu gốc như kết quả (bỏ qua hoa thường, dấu cuối câu).
                return expected.contains {
                    ResultCache<Int>.normalize(CorrectionNormalizer.reconcile(original: input, corrected: $0)) == out
                }
            }
            return out == ResultCache<Int>.normalize(input)
        }
    }

    public var items: [Item] = []
    public init() {}

    private var correctItems: [Item] { items.filter { $0.expected == nil } }
    private var incorrectItems: [Item] { items.filter { $0.expected != nil } }

    /// Tỉ lệ câu đúng được giữ nguyên.
    public var keepRate: Double { rate(correctItems.filter(\.passed).count, correctItems.count) }
    /// Tỉ lệ câu sai được sửa khớp đáp án.
    public var matchRate: Double { rate(incorrectItems.filter(\.passed).count, incorrectItems.count) }
    /// Tỉ lệ kết quả bị EditGuard loại vì viết lại câu.
    public var rewriteRate: Double { rate(items.filter { $0.verdict == .rewritten }.count, items.count) }

    public var p50: Double { percentile(0.5) }
    public var p95: Double { percentile(0.95) }

    private func rate(_ n: Int, _ total: Int) -> Double { total == 0 ? 0 : Double(n) / Double(total) }

    private func percentile(_ p: Double) -> Double {
        let sorted = items.map(\.seconds).sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, Int((Double(sorted.count) * p).rounded(.up)) - 1)
        return sorted[max(0, index)]
    }
}
