import Foundation

/// Cache LRU chỉ trong bộ nhớ (không ghi xuống đĩa).
public struct ResultCache<Value>: Sendable where Value: Sendable {
    public let capacity: Int
    private var storage: [String: Value] = [:]
    /// Thứ tự dùng gần nhất, phần tử cuối là mới nhất.
    private var order: [String] = []

    public init(capacity: Int = 200) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    public var count: Int { storage.count }

    /// Chuẩn hoá key: bỏ khoảng trắng hai đầu và gộp khoảng trắng liên tiếp.
    public static func normalize(_ sentence: String) -> String {
        sentence.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public mutating func value(for sentence: String) -> Value? {
        let key = Self.normalize(sentence)
        guard let value = storage[key] else { return nil }
        touch(key)
        return value
    }

    public mutating func insert(_ value: Value, for sentence: String) {
        let key = Self.normalize(sentence)
        storage[key] = value
        touch(key)
        while order.count > capacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }

    private mutating func touch(_ key: String) {
        if let index = order.firstIndex(of: key) { order.remove(at: index) }
        order.append(key)
    }
}
