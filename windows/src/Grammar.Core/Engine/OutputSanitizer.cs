namespace Grammar.Core.Engine;

/// <summary>
/// Làm sạch output của LLM: bỏ tiền tố, ngoặc kép bao ngoài, chỉ lấy dòng đầu.
/// Port của GrammarKit/Engine/OutputSanitizer.swift.
/// </summary>
public static class OutputSanitizer
{
    private static readonly string[] Prefixes =
    [
        "corrected text:", "corrected sentence:", "corrected:", "correction:",
        "text:", "output:", "answer:",
    ];

    private static readonly (char Open, char Close)[] QuotePairs =
    [
        ('"', '"'), ('“', '”'), ('\'', '\''), ('‘', '’'), ('`', '`'),
    ];

    private static readonly char[] Newlines = ['\n', '\r', '\u2028', '\u2029', '\u0085', '\v', '\f'];

    /// <param name="output">Text thô mô hình sinh ra.</param>
    /// <param name="original">Câu gốc. Dùng để giữ ngoặc kép nếu câu gốc vốn có, và làm giá trị dự phòng khi output rỗng.</param>
    public static string Clean(string output, string original)
    {
        var text = output
            .Split(Newlines, StringSplitOptions.None)
            .Select(TrimSpaces)
            .FirstOrDefault(l => l.Length > 0) ?? "";

        // Bỏ tiền tố kiểu "Corrected:" (lặp vì có thể có "Corrected text: Text: ...").
        var stripped = true;
        while (stripped)
        {
            stripped = false;
            var lower = text.ToLowerInvariant();
            foreach (var prefix in Prefixes)
            {
                if (!lower.StartsWith(prefix, StringComparison.Ordinal)) continue;
                text = TrimSpaces(text[prefix.Length..]);
                stripped = true;
                break;
            }
        }

        // Bỏ ngoặc kép bao ngoài, trừ khi câu gốc cũng được bao như vậy.
        var trimmedOriginal = TrimSpaces(original);
        foreach (var (open, close) in QuotePairs)
        {
            var originalQuoted = trimmedOriginal.Length > 0 && trimmedOriginal[0] == open && trimmedOriginal[^1] == close;
            if (text.Length >= 2 && text[0] == open && text[^1] == close && !originalQuoted)
            {
                text = TrimSpaces(text[1..^1]);
                break;
            }
        }

        return text.Length == 0 ? trimmedOriginal : text;
    }

    /// <summary>Bỏ khoảng trắng (không gồm xuống dòng) ở hai đầu, như <c>.whitespaces</c> của Swift.</summary>
    private static string TrimSpaces(string s) =>
        s.Trim(' ', '\t', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
            ' ', ' ', ' ', ' ', ' ', ' ', '　');
}
