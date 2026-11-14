using Grammar.Core.Text;

namespace Grammar.Core.Diff;

/// <summary>Một token (từ hoặc dấu câu) cùng vị trí (UTF-16) của nó trong chuỗi gốc.</summary>
public readonly record struct TextToken(string Text, int Start, int Length)
{
    public int End => Start + Length;
}

/// <summary>
/// Tách câu thành từ và dấu câu, bỏ qua khoảng trắng. Port của <c>WordTokenizer</c> (GrammarKit/Diff/Tokenizer.swift).
/// <list type="bullet">
/// <item>Từ: chuỗi chữ/số liền nhau, cho phép dấu nháy và gạch nối <i>ở giữa</i> (don't, well-known).</item>
/// <item>Mỗi ký tự còn lại (không phải khoảng trắng) là một token dấu câu riêng.</item>
/// </list>
/// </summary>
public static class WordTokenizer
{
    public static List<TextToken> Tokenize(string text)
    {
        var chars = Graphemes.Split(text);
        var tokens = new List<TextToken>();
        var index = 0;

        while (index < chars.Count)
        {
            var c = chars[index];

            if (Graphemes.IsWhitespace(text, c))
            {
                index++;
                continue;
            }

            if (Graphemes.IsLetterOrNumber(text, c))
            {
                var start = index;
                var end = index + 1;
                while (end < chars.Count)
                {
                    var next = chars[end];
                    if (Graphemes.IsLetterOrNumber(text, next))
                    {
                        end++;
                    }
                    else if (IsInnerJoiner(text, next))
                    {
                        // Chỉ nhận nháy/gạch nối khi phía sau tiếp tục là chữ.
                        var after = end + 1;
                        if (after < chars.Count && Graphemes.IsLetterOrNumber(text, chars[after]))
                            end = after + 1;
                        else
                            break;
                    }
                    else
                    {
                        break;
                    }
                }
                tokens.Add(Make(text, chars[start].Start, chars[end - 1].End));
                index = end;
            }
            else
            {
                tokens.Add(Make(text, c.Start, c.End));
                index++;
            }
        }
        return tokens;
    }

    private static TextToken Make(string text, int start, int end) =>
        new(text.Substring(start, end - start), start, end - start);

    private static bool IsInnerJoiner(string text, Graphemes.Element e)
    {
        if (e.Length != 1) return false;
        var ch = text[e.Start];
        return ch is '\'' or '’' or '-';
    }
}
