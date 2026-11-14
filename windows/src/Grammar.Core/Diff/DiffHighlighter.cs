using Grammar.Core.Text;

namespace Grammar.Core.Diff;

/// <summary>Các vùng cần đánh dấu khi hiển thị một <see cref="WordDiff"/> (UTF-16).</summary>
public sealed record DiffHighlights(
    IReadOnlyList<TextSpan> Underlines,
    IReadOnlyList<TextSpan> Gaps,
    IReadOnlyList<TextSpan> Insertions);

/// <summary>Kiểu hiển thị của một đoạn chữ trên panel.</summary>
public enum SegmentStyle
{
    Plain,
    /// <summary>Câu gốc: từ bị xoá hoặc thay. Gạch chân đỏ.</summary>
    Error,
    /// <summary>Câu gốc: chỗ thiếu từ. Nền đỏ nhạt và gạch chân đỏ.</summary>
    Gap,
    /// <summary>Câu sửa: từ được thêm hoặc thay. Chữ xanh, in đậm.</summary>
    Fix,
}

/// <summary>Một đoạn chữ liền nhau có cùng kiểu hiển thị.</summary>
public readonly record struct StyledSegment(string Text, SegmentStyle Style);

/// <summary>
/// Tính vùng đánh dấu và chia câu thành các đoạn có kiểu để UI vẽ.
/// Port của GrammarKit/Diff/DiffHighlighter.swift (bản Swift trả về AttributedString cho SwiftUI;
/// ở đây trả về danh sách đoạn thuần để test được và để WPF dựng <c>Run</c>).
/// </summary>
public static class DiffHighlighter
{
    public static DiffHighlights Highlights(WordDiff diff)
    {
        var original = diff.Original;
        return new DiffHighlights(
            diff.RemovedRanges,
            diff.MissingPositions.Select(p => GapRange(original, p)).OfType<TextSpan>().ToList(),
            diff.InsertedRanges);
    }

    /// <summary>
    /// Ký tự dùng để đánh dấu chỗ thiếu từ: ký tự (thường là khoảng trắng) tại vị trí đó nếu có,
    /// nếu không thì ký tự cuối cùng.
    /// </summary>
    internal static TextSpan? GapRange(string text, int position)
    {
        if (text.Length == 0) return null;
        var chars = Graphemes.Split(text);
        if (position < text.Length)
        {
            var e = chars.First(c => c.End > position);
            return new TextSpan(e.Start, e.Length);
        }
        var last = chars[^1];
        return new TextSpan(last.Start, last.Length);
    }

    /// <summary>Câu gốc: gạch chân đỏ cụm sai, đánh dấu chỗ thiếu từ.</summary>
    public static IReadOnlyList<StyledSegment> OriginalSegments(WordDiff diff)
    {
        var h = Highlights(diff);
        var styles = new SegmentStyle[diff.Original.Length];
        foreach (var span in h.Underlines) Fill(styles, span, SegmentStyle.Error);
        foreach (var span in h.Gaps) Fill(styles, span, SegmentStyle.Gap);
        return Merge(diff.Original, styles);
    }

    /// <summary>Câu sửa: tô xanh phần được thêm/thay.</summary>
    public static IReadOnlyList<StyledSegment> CorrectedSegments(WordDiff diff)
    {
        var styles = new SegmentStyle[diff.Corrected.Length];
        foreach (var span in diff.InsertedRanges) Fill(styles, span, SegmentStyle.Fix);
        return Merge(diff.Corrected, styles);
    }

    /// <summary>Cả câu một kiểu (dùng khi không có diff, ví dụ câu đúng hoặc đang kiểm tra).</summary>
    public static IReadOnlyList<StyledSegment> Plain(string text) =>
        text.Length == 0 ? [] : [new StyledSegment(text, SegmentStyle.Plain)];

    private static void Fill(SegmentStyle[] styles, TextSpan span, SegmentStyle style)
    {
        for (var i = span.Start; i < span.End && i < styles.Length; i++) styles[i] = style;
    }

    private static List<StyledSegment> Merge(string text, SegmentStyle[] styles)
    {
        var result = new List<StyledSegment>();
        var start = 0;
        for (var i = 1; i <= text.Length; i++)
        {
            if (i == text.Length || styles[i] != styles[start])
            {
                result.Add(new StyledSegment(text[start..i], styles[start]));
                start = i;
            }
        }
        return result;
    }
}
