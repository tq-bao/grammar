using System.Text.Json;
using Grammar.Core.Text;

namespace Grammar.Core.Tests;

public class SentenceSegmenterTests
{
    private static List<string> Split(string text) =>
        SentenceSegmenter.SentenceRanges(text).Select(r => text[r.Start..r.End]).ToList();

    [Fact]
    public void SplitsOnTerminatorsAndKeepsTrailingSpace() =>
        Assert.Equal(["I like tea. ", "He have two cats. ", "We are fine."], Split("I like tea. He have two cats. We are fine."));

    [Fact]
    public void QuestionAndExclamationAlwaysSplit() =>
        Assert.Equal(["what?? ", "really!! ", "ok."], Split("what?? really!! ok."));

    [Fact]
    public void LowercaseAfterPeriodStaysInSentence() =>
        Assert.Equal(["the datas shows that sales has increase. we need more"],
            Split("the datas shows that sales has increase. we need more"));

    [Fact]
    public void Abbreviations()
    {
        Assert.Equal(["Mr. Smith is here. ", "He wants tea."], Split("Mr. Smith is here. He wants tea."));
        Assert.Equal(["We met Dr. Lee yesterday. ", "She was nice."], Split("We met Dr. Lee yesterday. She was nice."));
        Assert.Equal(["Use e.g. a hash map. ", "It is faster."], Split("Use e.g. a hash map. It is faster."));
    }

    [Fact]
    public void DecimalsDomainsAndVersionsDoNotSplit()
    {
        Assert.Equal(["It costs 3.14 dollars. ", "Cheap!"], Split("It costs 3.14 dollars. Cheap!"));
        Assert.Equal(["Check example.com for details. ", "Then reply."], Split("Check example.com for details. Then reply."));
        Assert.Equal(["Version v1.2 is out. ", "Please update."], Split("Version v1.2 is out. Please update."));
        Assert.Equal(["I am fine.Thanks for asking."], Split("I am fine.Thanks for asking."));
    }

    [Fact]
    public void EllipsisDoesNotSplit()
    {
        Assert.Equal(["This is it… Done."], Split("This is it… Done."));
        Assert.Equal(["Wait... what happened? ", "I don't know."], Split("Wait... what happened? I don't know."));
    }

    [Fact]
    public void NewlinesSplit()
    {
        Assert.Equal(["first line\n", "second line"], Split("first line\nsecond line"));
        Assert.Equal(["line one.\r\n", "line two."], Split("line one.\r\nline two."));
    }

    [Fact]
    public void ClosingQuotesStayWithSentence() =>
        Assert.Equal(["He said \"stop.\" ", "Then he left."], Split("He said \"stop.\" Then he left."));

    [Fact]
    public void Count()
    {
        Assert.Equal(1, SentenceSegmenter.Count("I went home and I was tired and I slept early"));
        Assert.Equal(2, SentenceSegmenter.Count("I went home and I was tired. I slept early."));
        Assert.Equal(0, SentenceSegmenter.Count("  \n "));
    }
}

/// <summary>
/// Đối chiếu với <c>NLTokenizer(unit: .sentence)</c> thật của macOS
/// (Fixtures/sentences-nltokenizer.json, sinh bằng windows/scripts/gen-sentence-fixture.swift).
/// </summary>
public class SentenceSegmenterParityTests
{
    private sealed record Case(string Text, string[] Sentences);

    /// <summary>
    /// Khác biệt đã biết và chấp nhận: NLTokenizer tách sau "J." nhưng không tách sau "A." trong "Plan A.",
    /// nên không có quy tắc đơn giản nào khớp cả hai. Ở đây chữ cái viết hoa đứng riêng không tách câu.
    /// </summary>
    private static readonly HashSet<string> KnownDifferences = ["J. K. Rowling wrote it. I read it."];

    [Fact]
    public void MatchesNLTokenizer()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "sentences-nltokenizer.json"));
        var cases = JsonSerializer.Deserialize<Case[]>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
        Assert.True(cases.Length >= 30);

        var failures = new List<string>();
        foreach (var c in cases.Where(c => !KnownDifferences.Contains(c.Text)))
        {
            // NLTokenizer trả cả câu chỉ toàn khoảng trắng; SentenceRanges bỏ chúng (bản Swift cũng lọc khi dùng).
            var expected = c.Sentences.Where(s => !string.IsNullOrWhiteSpace(s)).ToList();
            var actual = SentenceSegmenter.SentenceRanges(c.Text).Select(r => c.Text[r.Start..r.End]).ToList();
            if (!expected.SequenceEqual(actual))
                failures.Add($"{JsonSerializer.Serialize(c.Text)}\n  NL: {JsonSerializer.Serialize(expected)}\n  C#: {JsonSerializer.Serialize(actual)}");
        }
        Assert.True(failures.Count == 0, string.Join("\n", failures));
    }
}
