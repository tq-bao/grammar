namespace Grammar.Core.Pipeline;

/// <summary>
/// Chuẩn hoá đoạn văn chứa con trỏ đọc được qua UI Automation (TextPattern2/TextPattern).
/// Port của GrammarKit/Pipeline/CaretContext.swift.
/// </summary>
/// <remarks>
/// App trả về đoạn văn và phần từ đầu đoạn tới con trỏ dưới dạng hai chuỗi riêng. Vị trí con trỏ là
/// độ dài phần đầu đoạn (UTF-16), cùng hệ với <see cref="SentenceExtractor"/>.
/// </remarks>
public static class CaretContext
{
    /// <summary>Ký tự thay thế cho phần tử nhúng (ảnh, mention, emoji tuỳ biến…).</summary>
    internal const char ObjectReplacement = '\uFFFC';

    /// <param name="paragraph">Đoạn văn chứa con trỏ.</param>
    /// <param name="prefix">Phần từ đầu đoạn tới con trỏ.</param>
    /// <returns>Đoạn văn đã bỏ ký tự phần tử nhúng, và vị trí con trỏ (UTF-16) trong đoạn đó.</returns>
    public static (string Text, int Cursor) Normalize(string paragraph, string prefix)
    {
        var text = paragraph.Replace(ObjectReplacement.ToString(), "", StringComparison.Ordinal);
        var head = prefix.Replace(ObjectReplacement.ToString(), "", StringComparison.Ordinal);
        return (text, Math.Min(head.Length, text.Length));
    }
}
