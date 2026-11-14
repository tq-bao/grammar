namespace Grammar.Core.Text;

/// <summary>
/// Tách đoạn văn thành câu theo quy tắc, thay cho <c>NLTokenizer(unit: .sentence)</c> của macOS
/// (không có trên Windows). Dùng chung cho <c>SentenceExtractor</c> và <c>EditGuard</c>.
/// </summary>
/// <remarks>
/// Các quy tắc được chỉnh theo kết quả của <c>NLTokenizer</c> thật (xem Fixtures/sentences-nltokenizer.json
/// và windows/scripts/gen-sentence-fixture.swift). Giống <c>NLTokenizer</c>, mỗi câu gồm cả khoảng trắng
/// theo sau nó: con trỏ đứng ngay sau dấu chấm (trước khoảng trắng) vẫn thuộc câu vừa kết thúc.
/// <list type="bullet">
/// <item><c>?</c> và <c>!</c> theo sau là khoảng trắng hoặc hết chuỗi: luôn kết thúc câu.</item>
/// <item><c>.</c> theo sau là khoảng trắng: kết thúc câu, trừ khi chữ tiếp theo viết thường,
/// hoặc đứng sau từ viết tắt (Mr., e.g.) hay một chữ cái viết hoa đứng riêng (Plan A., J. K.).</item>
/// <item>Dấu ba chấm (<c>…</c>, <c>...</c>) không kết thúc câu.</item>
/// <item>Mỗi lần xuống dòng là một ranh giới.</item>
/// <item>Dấu chấm không có khoảng trắng theo sau (3.14, example.com, fine.Thanks) không tách câu.</item>
/// </list>
/// </remarks>
public static class SentenceSegmenter
{
    /// <summary>Từ viết tắt (viết thường, không có dấu chấm cuối) mà dấu chấm theo sau không kết thúc câu.</summary>
    private static readonly HashSet<string> Abbreviations = new(StringComparer.Ordinal)
    {
        "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "mt", "ft",
        "e.g", "i.e", "a.m", "p.m", "u.s", "u.k", "u.s.a", "approx", "dept", "fig", "eg", "ie",
    };

    private static bool IsTerminator(char c) => c is '.' or '!' or '?' or '…' or '。' or '！' or '？';

    private static bool IsCloser(char c) => c is ')' or ']' or '}' or '"' or '\'' or '”' or '’' or '»';

    private static bool IsNewline(char c) => c is '\n' or '\r' or '\u2028' or '\u2029' or '\u0085';

    /// <summary>Các vùng câu (UTF-16, gồm khoảng trắng theo sau), bỏ qua câu chỉ toàn khoảng trắng.</summary>
    public static List<(int Start, int End)> SentenceRanges(string text)
    {
        var raw = new List<(int Start, int End)>();
        var start = 0;
        var i = 0;
        while (i < text.Length)
        {
            var c = text[i];

            if (IsNewline(c))
            {
                var end = ConsumeNewline(text, i);
                raw.Add((start, end));
                start = i = end;
                continue;
            }

            if (IsTerminator(c))
            {
                var clusterEnd = i + 1;
                while (clusterEnd < text.Length && IsTerminator(text[clusterEnd])) clusterEnd++;
                var end = clusterEnd;
                while (end < text.Length && IsCloser(text[end])) end++;

                if (EndsSentence(text, start, i, clusterEnd, end))
                {
                    end = ConsumeTrailingWhitespace(text, end);
                    raw.Add((start, end));
                    start = i = end;
                }
                else
                {
                    i = end;
                }
                continue;
            }
            i++;
        }
        if (start < text.Length) raw.Add((start, text.Length));

        return raw.Where(r => !string.IsNullOrWhiteSpace(text[r.Start..r.End])).ToList();
    }

    /// <summary>Số câu không rỗng trong chuỗi.</summary>
    public static int Count(string text) => SentenceRanges(text).Count;

    /// <summary>Cụm dấu kết câu <c>text[clusterStart..clusterEnd]</c> (kèm dấu đóng tới <paramref name="end"/>) có kết thúc câu không.</summary>
    private static bool EndsSentence(string text, int sentenceStart, int clusterStart, int clusterEnd, int end)
    {
        if (end < text.Length && !char.IsWhiteSpace(text[end])) return false;

        var cluster = text[clusterStart..clusterEnd];
        if (cluster.Contains('?') || cluster.Contains('!') || cluster.Contains('？') || cluster.Contains('！'))
            return true;
        // Dấu ba chấm.
        if (cluster.Contains('…') || cluster.Count(ch => ch == '.') >= 2) return false;

        if (end >= text.Length) return true;
        if (IsAbbreviationBefore(text, sentenceStart, clusterStart)) return false;

        // Chữ tiếp theo viết thường: vẫn là cùng một câu.
        var next = end;
        while (next < text.Length && char.IsWhiteSpace(text[next]) && !IsNewline(text[next])) next++;
        return next >= text.Length || IsNewline(text[next]) || !char.IsLower(text[next]);
    }

    /// <summary>Gom khoảng trắng theo sau câu, gồm tối đa một lần xuống dòng.</summary>
    private static int ConsumeTrailingWhitespace(string text, int end)
    {
        while (end < text.Length && char.IsWhiteSpace(text[end]))
        {
            if (IsNewline(text[end])) return ConsumeNewline(text, end);
            end++;
        }
        return end;
    }

    /// <summary>Vị trí ngay sau ký tự xuống dòng tại <paramref name="i"/> (CR LF tính là một).</summary>
    private static int ConsumeNewline(string text, int i) =>
        text[i] == '\r' && i + 1 < text.Length && text[i + 1] == '\n' ? i + 2 : i + 1;

    /// <summary>Dấu chấm ở <paramref name="dot"/> đứng sau một từ viết tắt hoặc một chữ cái viết hoa đứng riêng.</summary>
    private static bool IsAbbreviationBefore(string text, int sentenceStart, int dot)
    {
        // Từ ngay trước dấu chấm: chữ cái và dấu chấm liền nhau (để bắt "e.g", "U.S").
        var wordStart = dot;
        while (wordStart > sentenceStart && (char.IsLetter(text[wordStart - 1]) || text[wordStart - 1] == '.'))
            wordStart--;
        var word = text[wordStart..dot];
        if (word.Length == 0) return false;
        if (Abbreviations.Contains(word.ToLowerInvariant())) return true;
        return word.Length == 1 && char.IsUpper(word[0]);
    }
}
