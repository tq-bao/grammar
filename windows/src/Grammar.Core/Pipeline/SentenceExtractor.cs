using Grammar.Core.Text;

namespace Grammar.Core.Pipeline;

/// <summary>
/// Lấy ra câu đang chứa con trỏ trong nội dung một ô nhập liệu.
/// Port của GrammarKit/Pipeline/SentenceExtractor.swift (dùng <see cref="SentenceSegmenter"/> thay NLTokenizer).
/// </summary>
public static class SentenceExtractor
{
    /// <param name="text">Toàn bộ nội dung ô nhập liệu (hoặc đoạn văn chứa con trỏ).</param>
    /// <param name="cursorUtf16Offset">
    /// Vị trí con trỏ tính theo UTF-16 (đơn vị mà UI Automation và <see cref="string"/> dùng).
    /// <c>null</c> khi app không cung cấp: khi đó lấy câu cuối cùng.
    /// </param>
    /// <returns>Câu đã bỏ khoảng trắng hai đầu, hoặc <c>null</c> nếu ô trống.</returns>
    public static string? Sentence(string text, int? cursorUtf16Offset)
    {
        var ranges = SentenceSegmenter.SentenceRanges(text);
        if (ranges.Count == 0) return null;

        if (cursorUtf16Offset is not { } offset) return Trimmed(text, ranges[^1]);

        var cursor = Math.Clamp(offset, 0, text.Length);

        // Ưu tiên câu có con trỏ nằm hẳn bên trong. Con trỏ ở ngay cuối text thì thuộc câu cuối.
        foreach (var r in ranges)
            if (r.Start <= cursor && cursor < r.End) return Trimmed(text, r);
        for (var i = ranges.Count - 1; i >= 0; i--)
            if (ranges[i].Start <= cursor) return Trimmed(text, ranges[i]);
        return Trimmed(text, ranges[0]);
    }

    private static string? Trimmed(string text, (int Start, int End) range)
    {
        var t = text[range.Start..range.End].Trim();
        return t.Length == 0 ? null : t;
    }
}
