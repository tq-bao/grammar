// Sinh fixture đối chiếu thuật toán diff: chạy `difference(from:)` thật của Swift trên các cặp
// dãy token ngẫu nhiên (bộ từ nhỏ để có nhiều từ trùng, nhiều cách ghép cặp).
// Test C# MyersParityTests đọc file này để chắc bản port chọn đúng nhánh như Swift.
//
//   swift windows/scripts/gen-myers-fixture.swift > windows/tests/Grammar.Core.Tests/Fixtures/myers-swift.json
import Foundation

struct Seeded: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
var gen = Seeded(state: 42)
let vocab = ["a", "b", "c", "the", "is", "."]

var cases: [[String: Any]] = []
for _ in 0..<500 {
    let n = Int.random(in: 0...16, using: &gen)
    let m = Int.random(in: 0...16, using: &gen)
    let a = (0..<n).map { _ in vocab.randomElement(using: &gen)! }
    let b = (0..<m).map { _ in vocab.randomElement(using: &gen)! }
    var removed: [Int] = []
    var inserted: [Int] = []
    for change in b.difference(from: a) {
        switch change {
        case let .remove(offset, _, _): removed.append(offset)
        case let .insert(offset, _, _): inserted.append(offset)
        }
    }
    cases.append(["a": a, "b": b, "removed": removed.sorted(), "inserted": inserted.sorted()])
}
let data = try JSONSerialization.data(withJSONObject: cases, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
