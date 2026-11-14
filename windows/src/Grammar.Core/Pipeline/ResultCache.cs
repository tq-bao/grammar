namespace Grammar.Core.Pipeline;

/// <summary>
/// Cache LRU chỉ trong bộ nhớ (không ghi xuống đĩa). Port của GrammarKit/Pipeline/ResultCache.swift.
/// </summary>
public sealed class ResultCache<TValue>
{
    private readonly Dictionary<string, LinkedListNode<(string Key, TValue Value)>> _storage = new(StringComparer.Ordinal);
    /// <summary>Thứ tự dùng gần nhất, phần tử cuối là mới nhất.</summary>
    private readonly LinkedList<(string Key, TValue Value)> _order = new();

    public ResultCache(int capacity = 200)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(capacity);
        Capacity = capacity;
    }

    public int Capacity { get; }

    public int Count => _storage.Count;

    /// <summary>Chuẩn hoá key: bỏ khoảng trắng hai đầu và gộp khoảng trắng liên tiếp.</summary>
    public static string Normalize(string sentence) =>
        string.Join(' ', sentence.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));

    public bool TryGetValue(string sentence, out TValue value)
    {
        if (_storage.TryGetValue(Normalize(sentence), out var node))
        {
            _order.Remove(node);
            _order.AddLast(node);
            value = node.Value.Value;
            return true;
        }
        value = default!;
        return false;
    }

    public void Insert(TValue value, string sentence)
    {
        var key = Normalize(sentence);
        if (_storage.TryGetValue(key, out var existing)) _order.Remove(existing);
        _storage[key] = _order.AddLast((key, value));
        while (_order.Count > Capacity)
        {
            var oldest = _order.First!;
            _order.RemoveFirst();
            _storage.Remove(oldest.Value.Key);
        }
    }
}
