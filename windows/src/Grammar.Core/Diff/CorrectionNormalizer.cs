namespace Grammar.Core.Diff;

/// <summary>
/// Đối chiếu câu sửa với câu gốc để bỏ qua những thứ người dùng không muốn kiểm tra.
/// Port của GrammarKit/Diff/CorrectionNormalizer.swift.
/// <list type="bullet">
/// <item>viết hoa/viết thường: từ chỉ khác hoa thường thì lấy lại đúng chữ của câu gốc;</item>
/// <item>dấu câu cuối câu: bỏ dấu cuối của câu sửa và gắn lại dấu cuối của câu gốc.</item>
/// </list>
/// </summary>
public static class CorrectionNormalizer
{
    /// <summary>Dấu câu ở cuối câu được bỏ qua khi kiểm tra.</summary>
    public static readonly IReadOnlySet<string> FinalPunctuation =
        new HashSet<string> { ".", ",", ";", ":", "!", "?", "…" };

    public static string Reconcile(string original, string corrected)
    {
        var a = WordTokenizer.Tokenize(original);
        var b = WordTokenizer.Tokenize(corrected);
        var aEnd = CoreEnd(a);
        var bEnd = CoreEnd(b);
        // Một trong hai câu chỉ toàn dấu câu: không có gì để sửa.
        if (aEnd <= 0 || bEnd <= 0) return original.Trim();

        // So khớp phần thân câu, không phân biệt hoa thường.
        var aWords = a.Take(aEnd).Select(t => t.Text.ToLowerInvariant()).ToList();
        var bWords = b.Take(bEnd).Select(t => t.Text.ToLowerInvariant()).ToList();
        var matches = MatchedPairs(aWords, bWords);

        // Dựng lại thân câu sửa: giữ khoảng trắng của câu sửa, từ khớp lấy chữ của câu gốc.
        var result = new System.Text.StringBuilder();
        var cursor = b[0].Start;
        for (var j = 0; j < bEnd; j++)
        {
            result.Append(corrected, cursor, b[j].Start - cursor);
            result.Append(matches[j] is { } i ? a[i].Text : b[j].Text);
            cursor = b[j].End;
        }

        // Gắn lại phần đuôi của câu gốc (dấu câu cuối, nếu có), bỏ khoảng trắng thừa ở cuối.
        var tail = original[a[aEnd - 1].End..].TrimEnd();
        return result.Append(tail).ToString();
    }

    /// <summary>Vị trí ngay sau token cuối cùng không phải dấu câu cuối câu.</summary>
    private static int CoreEnd(List<TextToken> tokens)
    {
        var end = tokens.Count;
        while (end > 0 && FinalPunctuation.Contains(tokens[end - 1].Text)) end--;
        return end;
    }

    /// <summary>Với mỗi token của <paramref name="b"/>, chỉ số token tương ứng trong <paramref name="a"/> nếu hai token khớp.</summary>
    private static int?[] MatchedPairs(List<string> a, List<string> b)
    {
        var (removed, inserted) = Myers.Diff(a, b);
        var result = new int?[b.Count];
        var i = 0;
        var j = 0;
        while (i < a.Count || j < b.Count)
        {
            if (i < a.Count && removed.Contains(i))
            {
                i++;
            }
            else if (j < b.Count && inserted.Contains(j))
            {
                j++;
            }
            else
            {
                if (j < b.Count && i < a.Count) result[j] = i;
                i++;
                j++;
            }
        }
        return result;
    }
}
