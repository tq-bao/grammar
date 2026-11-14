using Grammar.Core.Diff;

namespace Grammar.Core.Tests;

// Port của GrammarAppTests/DiffTests.swift (TokenizerTests, WordDiffTests, WordFormTests).

public class TokenizerTests
{
    private static List<string> Texts(string s) => WordTokenizer.Tokenize(s).Select(t => t.Text).ToList();

    [Fact]
    public void ApostrophesStayInsideWords() =>
        Assert.Equal(["I", "don't", "know", ",", "it's", "fine", "."], Texts("I don't know, it's fine."));

    [Fact]
    public void PunctuationAttachedToWords() =>
        Assert.Equal(["(", "Hello", ")", "!", "well-known", "'", "quote", "'"], Texts("(Hello)! well-known 'quote'"));

    [Fact]
    public void MultipleSpacesAndRangesPointIntoOriginal()
    {
        const string text = "  He   have  cats ";
        var tokens = WordTokenizer.Tokenize(text);
        Assert.Equal(["He", "have", "cats"], tokens.Select(t => t.Text));
        foreach (var token in tokens)
            Assert.Equal(token.Text, text.Substring(token.Start, token.Length));
    }

    [Fact]
    public void Empty() => Assert.Empty(WordTokenizer.Tokenize("   "));

    // Thêm cho bản C#: string là UTF-16, emoji và ký tự ngoài BMP không được bị cắt đôi.

    [Fact]
    public void EmojiIsOneTokenAndRangesAreUtf16()
    {
        const string text = "ok 👍🏽 thanks";
        var tokens = WordTokenizer.Tokenize(text);
        Assert.Equal(["ok", "👍🏽", "thanks"], tokens.Select(t => t.Text));
        Assert.Equal(3, tokens[1].Start);
        Assert.Equal("👍🏽".Length, tokens[1].Length);  // 4 đơn vị UTF-16
        Assert.Equal(8, tokens[2].Start);
    }

    [Fact]
    public void LettersOutsideBmpStayInsideWord()
    {
        // 𝐀 (U+1D400) là chữ cái, nằm ngoài BMP (cặp surrogate).
        var tokens = WordTokenizer.Tokenize("a𝐀b c");
        Assert.Equal(["a𝐀b", "c"], tokens.Select(t => t.Text));
    }

    [Fact]
    public void VietnameseCombiningMarksStayInsideWord()
    {
        // "ệ" viết dạng tổ hợp (e + dấu mũ + dấu nặng).
        const string decomposed = "Việt Nam";
        Assert.Equal(["Việt", "Nam"], Texts(decomposed));
    }
}

public class WordDiffTests
{
    [Fact]
    public void ReplacedWord()
    {
        var diff = new WordDiff("He have two cats.", "He has two cats.");
        Assert.Equal(["have"], diff.RemovedWords);
        Assert.Equal(["has"], diff.InsertedWords);
        Assert.Empty(diff.MissingPositions);
        Assert.False(diff.IsIdentical);
    }

    [Fact]
    public void MissingWord()
    {
        const string original = "I going home.";
        var diff = new WordDiff(original, "I am going home.");
        Assert.Empty(diff.RemovedWords);
        Assert.Equal(["am"], diff.InsertedWords);
        Assert.Single(diff.MissingPositions);
        // Vị trí thiếu từ nằm ngay sau "I".
        Assert.Equal("I", original[..diff.MissingPositions[0]]);
    }

    [Fact]
    public void MissingWordAtStart()
    {
        var diff = new WordDiff("cat is sleeping.", "The cat is sleeping.");
        Assert.Equal([0], diff.MissingPositions);
    }

    [Fact]
    public void IdenticalIgnoringWhitespace()
    {
        var diff = new WordDiff("I have  finished the report.", "I have finished the report.");
        Assert.True(diff.IsIdentical);
        Assert.Equal(0, diff.ChangeRatio);
    }

    [Fact]
    public void CapitalizationIsAChange()
    {
        var diff = new WordDiff("i am here.", "I am here.");
        Assert.Equal(["i"], diff.RemovedWords);
        Assert.Equal(["I"], diff.InsertedWords);
    }

    [Fact]
    public void MultipleEdits()
    {
        var diff = new WordDiff("He have two cats and they is cute.", "He has two cats and they are cute.");
        Assert.Equal(["have", "is"], diff.RemovedWords);
        Assert.Equal(["has", "are"], diff.InsertedWords);
        Assert.Equal(2, diff.RemovedTokenCount);
        Assert.Equal(9, diff.OriginalTokenCount);
    }

    [Fact]
    public void RangesAfterEmojiAreUtf16Offsets()
    {
        const string original = "🙂 He have cats";
        var diff = new WordDiff(original, "🙂 He has cats");
        Assert.Equal(["have"], diff.RemovedWords);
        Assert.Equal(original.IndexOf("have", StringComparison.Ordinal), diff.RemovedRanges[0].Start);
    }
}

public class WordFormTests
{
    [Fact]
    public void SameWordDifferentForms()
    {
        Assert.True(WordDiff.IsSameWord("collect", "collecting"));
        Assert.True(WordDiff.IsSameWord("envidences", "evidence"));
        Assert.True(WordDiff.IsSameWord("dont", "doesn't"));
        Assert.True(WordDiff.IsSameWord("has", "have"));
        Assert.False(WordDiff.IsSameWord("go", "went"));  // bất quy tắc: khác hẳn về chữ
        Assert.True(WordDiff.IsSameWord("Go", "goes"));
    }

    [Fact]
    public void DifferentWords()
    {
        Assert.False(WordDiff.IsSameWord("gonna", "will"));
        Assert.False(WordDiff.IsSameWord("file", "document"));
        Assert.False(WordDiff.IsSameWord("numbers", "figures"));
    }

    [Fact]
    public void DissimilarCount()
    {
        var fix = new WordDiff("I'm collect more envidences", "I'm collecting more evidence");
        Assert.Equal(2, fix.RemovedTokenCount);
        Assert.Equal(0, fix.DissimilarRemovedCount);

        var rewrite = new WordDiff(
            "gonna send u the file tmr, it have the numbers",
            "I will send you the document tomorrow; it contains the figures.");
        Assert.True(rewrite.DissimilarChangeRatio > 0.4);
    }
}

/// <summary>
/// Kiểm tra bản port Myers chọn đúng nhánh như <c>difference(from:)</c> của Swift
/// ở các trường hợp có nhiều cách ghép cặp tối ưu.
/// </summary>
public class MyersParityTests
{
    private static (int[] removed, int[] inserted) Run(string a, string b)
    {
        var (r, i) = Myers.Diff(a.Split(' '), b.Split(' '));
        return (r.Order().ToArray(), i.Order().ToArray());
    }

    [Fact]
    public void ReplacementIsRemoveAndInsertAtSameOffset()
    {
        var (removed, inserted) = Run("a b c", "a x c");
        Assert.Equal([1], removed);
        Assert.Equal([1], inserted);
    }

    [Fact]
    public void AmbiguousDuplicateWords()
    {
        // Swift: Array("a a b".split(" ")).difference(from: ["a", "b", "a"]) chỉ cần 1 xoá + 1 thêm.
        var (removed, inserted) = Run("a b a", "a a b");
        Assert.Single(removed);
        Assert.Single(inserted);
    }

    private sealed record SwiftCase(string[] A, string[] B, int[] Removed, int[] Inserted);

    /// <summary>
    /// 500 cặp dãy token ngẫu nhiên, kết quả lấy từ <c>difference(from:)</c> thật của Swift
    /// (sinh bằng windows/scripts/gen-myers-fixture.swift).
    /// </summary>
    [Fact]
    public void MatchesSwiftDifferenceOnRandomCases()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "myers-swift.json"));
        var cases = System.Text.Json.JsonSerializer.Deserialize<SwiftCase[]>(
            json, new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
        Assert.Equal(500, cases.Length);
        foreach (var c in cases)
        {
            var (removed, inserted) = Myers.Diff(c.A, c.B);
            var label = $"{string.Join(' ', c.A)} -> {string.Join(' ', c.B)}";
            Assert.True(c.Removed.SequenceEqual(removed.Order()), $"removed khác Swift: {label}");
            Assert.True(c.Inserted.SequenceEqual(inserted.Order()), $"inserted khác Swift: {label}");
        }
    }

    [Fact]
    public void Empty()
    {
        var (removed, inserted) = Myers.Diff([], ["x", "y"]);
        Assert.Empty(removed);
        Assert.Equal([0, 1], inserted.Order());
    }
}
