using System.Buffers;
using System.Globalization;
using System.Text;

namespace Grammar.Core.Text;

/// <summary>
/// Duyệt chuỗi theo từng ký tự người đọc thấy (grapheme cluster), tương đương <c>Character</c> của Swift.
/// Mọi vị trí tính theo đơn vị UTF-16 của <see cref="string"/>, cùng hệ với Accessibility/UI Automation.
/// </summary>
public static class Graphemes
{
    /// <summary>Một grapheme: vị trí bắt đầu và độ dài (UTF-16).</summary>
    public readonly record struct Element(int Start, int Length)
    {
        public int End => Start + Length;
    }

    public static IEnumerable<Element> Enumerate(string text)
    {
        var index = 0;
        while (index < text.Length)
        {
            var length = StringInfo.GetNextTextElementLength(text, index);
            if (length <= 0) length = 1;
            yield return new Element(index, length);
            index += length;
        }
    }

    public static List<Element> Split(string text) => Enumerate(text).ToList();

    /// <summary>Rune đầu tiên của grapheme. Swift xét <c>isLetter</c>/<c>isNumber</c> theo scalar đầu tiên.</summary>
    public static Rune FirstRune(string text, Element element) =>
        Rune.DecodeFromUtf16(text.AsSpan(element.Start, element.Length), out var rune, out _) == OperationStatus.Done
            ? rune
            : Rune.ReplacementChar;

    public static bool IsLetter(string text, Element e) => Rune.IsLetter(FirstRune(text, e));

    public static bool IsNumber(string text, Element e) => Rune.IsNumber(FirstRune(text, e));

    public static bool IsLetterOrNumber(string text, Element e)
    {
        var rune = FirstRune(text, e);
        return Rune.IsLetter(rune) || Rune.IsNumber(rune);
    }

    public static bool IsWhitespace(string text, Element e) => Rune.IsWhiteSpace(FirstRune(text, e));

    /// <summary>Chuỗi có ít nhất một chữ cái hoặc chữ số (Swift: <c>contains { $0.isLetter || $0.isNumber }</c>).</summary>
    public static bool ContainsLetterOrNumber(string text) =>
        Enumerate(text).Any(e => IsLetterOrNumber(text, e));

    public static bool ContainsLetter(string text) => Enumerate(text).Any(e => IsLetter(text, e));

    /// <summary>Danh sách grapheme dưới dạng chuỗi con, dùng để so sánh từng ký tự.</summary>
    public static string[] ToStrings(string text) =>
        Enumerate(text).Select(e => text.Substring(e.Start, e.Length)).ToArray();
}
