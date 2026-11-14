using Grammar.Core.Text;

namespace Grammar.Core.Diff;

/// <summary>Một vùng trong chuỗi, tính theo đơn vị UTF-16.</summary>
public readonly record struct TextSpan(int Start, int Length)
{
    public int End => Start + Length;

    public string Of(string text) => text.Substring(Start, Length);
}

/// <summary>
/// Kết quả so sánh câu gốc với câu đã sửa theo từng token. Port của GrammarKit/Diff/WordDiff.swift.
/// Dùng cho cả hiển thị (gạch chân đỏ ở câu gốc, tô nổi bật ở câu sửa) lẫn <see cref="EditGuard"/>.
/// </summary>
public sealed class WordDiff : IEquatable<WordDiff>
{
    public string Original { get; }
    public string Corrected { get; }

    /// <summary>Vùng trong <see cref="Original"/> bị xoá hoặc bị thay (cần gạch chân đỏ).</summary>
    public IReadOnlyList<TextSpan> RemovedRanges { get; }
    /// <summary>Vùng trong <see cref="Corrected"/> được thêm vào hoặc thay đổi (cần tô nổi bật).</summary>
    public IReadOnlyList<TextSpan> InsertedRanges { get; }
    /// <summary>Vị trí (UTF-16) trong <see cref="Original"/> bị thiếu từ: câu sửa chèn thêm từ mà không xoá gì ở đó.</summary>
    public IReadOnlyList<int> MissingPositions { get; }

    public int OriginalTokenCount { get; }
    public int RemovedTokenCount { get; }
    /// <summary>Số token gốc bị thay bằng một từ khác hẳn (không tính sửa dạng từ/chính tả, không tính dấu câu).</summary>
    public int DissimilarRemovedCount { get; }

    /// <summary>Hai câu giống nhau (bỏ qua khác biệt về khoảng trắng).</summary>
    public bool IsIdentical => RemovedRanges.Count == 0 && InsertedRanges.Count == 0;

    /// <summary>Tỉ lệ token gốc bị xoá/thay, từ 0 đến 1.</summary>
    public double ChangeRatio =>
        OriginalTokenCount > 0
            ? (double)RemovedTokenCount / OriginalTokenCount
            : (InsertedRanges.Count == 0 ? 0 : 1);

    /// <summary>Tỉ lệ token gốc bị thay bằng một từ khác hẳn, từ 0 đến 1.</summary>
    public double DissimilarChangeRatio =>
        OriginalTokenCount > 0
            ? (double)DissimilarRemovedCount / OriginalTokenCount
            : (InsertedRanges.Count == 0 ? 0 : 1);

    /// <summary>Các đoạn text bị gạch chân trong câu gốc (tiện cho test và debug).</summary>
    public IReadOnlyList<string> RemovedWords => RemovedRanges.Select(r => r.Of(Original)).ToList();
    /// <summary>Các đoạn text được tô nổi bật trong câu sửa.</summary>
    public IReadOnlyList<string> InsertedWords => InsertedRanges.Select(r => r.Of(Corrected)).ToList();

    public WordDiff(string original, string corrected)
    {
        Original = original;
        Corrected = corrected;

        var a = WordTokenizer.Tokenize(original);
        var b = WordTokenizer.Tokenize(corrected);
        // So sánh phân biệt hoa thường để lỗi viết hoa ("i am" -> "I am") cũng được đánh dấu.
        var (removed, inserted) = Myers.Diff(a.Select(t => t.Text).ToList(), b.Select(t => t.Text).ToList());

        var removedRanges = new List<TextSpan>();
        var insertedRanges = new List<TextSpan>();
        var missing = new List<int>();

        // Duyệt song song hai dãy token để gom các nhóm thay đổi nằm giữa hai token giữ nguyên.
        var i = 0;
        var j = 0;
        var groupHasRemoval = false;
        var groupHasInsertion = false;
        var groupRemoved = new List<string>();
        var groupInserted = new List<string>();
        var dissimilar = 0;

        void FlushGroup(int originalIndex)
        {
            dissimilar += UnmatchedCount(groupRemoved, groupInserted);
            groupRemoved = [];
            groupInserted = [];
            if (groupHasInsertion && !groupHasRemoval && a.Count > 0)
            {
                // Chèn thêm từ mà không xoá gì: đánh dấu vị trí ngay sau token đứng trước.
                var position = originalIndex > 0 ? a[originalIndex - 1].End : a[0].Start;
                missing.Add(position);
            }
            groupHasRemoval = false;
            groupHasInsertion = false;
        }

        while (i < a.Count || j < b.Count)
        {
            if (i < a.Count && removed.Contains(i))
            {
                removedRanges.Add(new TextSpan(a[i].Start, a[i].Length));
                groupRemoved.Add(a[i].Text);
                groupHasRemoval = true;
                i++;
            }
            else if (j < b.Count && inserted.Contains(j))
            {
                insertedRanges.Add(new TextSpan(b[j].Start, b[j].Length));
                groupInserted.Add(b[j].Text);
                groupHasInsertion = true;
                j++;
            }
            else
            {
                FlushGroup(i);
                i++;
                j++;
            }
        }
        FlushGroup(i);

        RemovedRanges = removedRanges;
        InsertedRanges = insertedRanges;
        MissingPositions = missing;
        OriginalTokenCount = a.Count;
        RemovedTokenCount = removed.Count;
        DissimilarRemovedCount = dissimilar;
    }

    // ---- Sửa dạng từ / chính tả ----

    /// <summary>Số từ bị xoá trong một nhóm thay đổi mà không ghép được với từ thêm vào nào "gần giống".</summary>
    internal static int UnmatchedCount(IReadOnlyList<string> removed, IReadOnlyList<string> inserted)
    {
        var available = inserted.ToList();
        var unmatched = 0;
        foreach (var word in removed)
        {
            if (IsPunctuation(word)) continue;  // thay/xoá dấu câu không tính là viết lại
            var index = available.FindIndex(w => IsSameWord(word, w));
            if (index >= 0)
                available.RemoveAt(index);
            else
                unmatched++;
        }
        return unmatched;
    }

    /// <summary>
    /// Hai từ được coi là cùng một từ (chỉ khác dạng hoặc chính tả): là tiền tố của nhau (tối thiểu 3 ký tự),
    /// hoặc khoảng cách Levenshtein ≤ 50% độ dài từ dài hơn.
    /// </summary>
    internal static bool IsSameWord(string a, string b)
    {
        var x = Graphemes.ToStrings(a.ToLowerInvariant());
        var y = Graphemes.ToStrings(b.ToLowerInvariant());
        if (x.Length == 0 || y.Length == 0) return false;
        if (Math.Min(x.Length, y.Length) >= 3 && (StartsWith(x, y) || StartsWith(y, x))) return true;
        return Levenshtein(x, y) <= 0.5 * Math.Max(x.Length, y.Length);
    }

    internal static bool IsPunctuation(string token) => !Graphemes.ContainsLetterOrNumber(token);

    private static bool StartsWith(string[] s, string[] prefix) =>
        prefix.Length <= s.Length && s.AsSpan(0, prefix.Length).SequenceEqual(prefix);

    internal static int Levenshtein(string[] x, string[] y)
    {
        if (x.Length == 0) return y.Length;
        if (y.Length == 0) return x.Length;
        var previous = Enumerable.Range(0, y.Length + 1).ToArray();
        var current = new int[y.Length + 1];
        for (var i = 1; i <= x.Length; i++)
        {
            current[0] = i;
            for (var j = 1; j <= y.Length; j++)
            {
                var cost = x[i - 1] == y[j - 1] ? 0 : 1;
                current[j] = Math.Min(Math.Min(previous[j] + 1, current[j - 1] + 1), previous[j - 1] + cost);
            }
            (previous, current) = (current, previous);
        }
        return previous[y.Length];
    }

    public bool Equals(WordDiff? other) =>
        other is not null && Original == other.Original && Corrected == other.Corrected;

    public override bool Equals(object? obj) => Equals(obj as WordDiff);

    public override int GetHashCode() => HashCode.Combine(Original, Corrected);
}
