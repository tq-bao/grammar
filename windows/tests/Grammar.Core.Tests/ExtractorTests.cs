using Grammar.Core.Pipeline;

namespace Grammar.Core.Tests;

// Port của SentenceExtractorTests (GrammarAppTests/PipelineTests.swift).
public class SentenceExtractorTests
{
    private const string Text = "I like tea. He have two cats. We are fine.";

    private static int OffsetOf(string needle) => Text.IndexOf(needle, StringComparison.Ordinal);

    [Fact]
    public void CursorInSecondSentence() =>
        Assert.Equal("He have two cats.", SentenceExtractor.Sentence(Text, OffsetOf("two")));

    [Fact]
    public void CursorInFirstSentence() => Assert.Equal("I like tea.", SentenceExtractor.Sentence(Text, 2));

    [Fact]
    public void CursorAtEndOfText() => Assert.Equal("We are fine.", SentenceExtractor.Sentence(Text, Text.Length));

    [Fact]
    public void NoCursorUsesLastSentence() => Assert.Equal("We are fine.", SentenceExtractor.Sentence(Text, null));

    [Fact]
    public void OutOfRangeCursorIsClamped() => Assert.Equal("We are fine.", SentenceExtractor.Sentence(Text, 10_000));

    [Fact]
    public void NegativeCursorIsClamped() => Assert.Equal("I like tea.", SentenceExtractor.Sentence(Text, -5));

    [Fact]
    public void EmptyText() => Assert.Null(SentenceExtractor.Sentence("   \n", 0));

    [Fact]
    public void EmojiBeforeCursorUsesUtf16Offsets()
    {
        const string t = "Nice 😀 day. She go home now.";
        Assert.Equal("She go home now.", SentenceExtractor.Sentence(t, t.Length - 2));
    }

    [Fact]
    public void CursorRightAfterPeriodBelongsToThatSentence() =>
        // Giống NLTokenizer: câu gồm cả khoảng trắng theo sau, con trỏ ở khoảng trắng vẫn thuộc câu trước.
        Assert.Equal("I like tea.", SentenceExtractor.Sentence(Text, OffsetOf(" He")));

    [Fact]
    public void CursorOnBlankLineUsesSentenceBefore()
    {
        const string t = "Hi team,\n\nI will send it.";
        Assert.Equal("Hi team,", SentenceExtractor.Sentence(t, t.IndexOf("\n\n", StringComparison.Ordinal) + 1));
    }
}

// Port của GrammarAppTests/CaretContextTests.swift.
public class CaretContextTests
{
    [Fact]
    public void ConfluenceParagraphWithCaretAtEnd()
    {
        // Giá trị đọc được từ Chrome khi gõ trong Confluence.
        const string paragraph = "I don’t want to mention";
        var (text, cursor) = CaretContext.Normalize(paragraph, paragraph);
        Assert.Equal(23, cursor);
        Assert.Equal("I don’t want to mention", SentenceExtractor.Sentence(text, cursor));
    }

    [Fact]
    public void CaretInsideParagraphPicksThatSentence()
    {
        const string paragraph = "Upgrade React Native from 0.83.1 to 0.87.1. It touches both apps. We bump react too.";
        const string prefix = "Upgrade React Native from 0.83.1 to 0.87.1. It touc";
        var (text, cursor) = CaretContext.Normalize(paragraph, prefix);
        Assert.Equal("It touches both apps.", SentenceExtractor.Sentence(text, cursor));
    }

    [Fact]
    public void ObjectReplacementCharactersAreRemovedKeepingCaretAligned()
    {
        const string paragraph = "Ping \uFFFC about it. She go home now.";
        const string prefix = "Ping \uFFFC about it. She go";
        var (text, cursor) = CaretContext.Normalize(paragraph, prefix);
        Assert.DoesNotContain('\uFFFC', text);
        Assert.Equal("Ping  about it. She go home now.", text);
        Assert.Equal("Ping  about it. She go".Length, cursor);
        Assert.Equal("She go home now.", SentenceExtractor.Sentence(text, cursor));
    }

    [Fact]
    public void PrefixLongerThanParagraphIsClamped()
    {
        var (text, cursor) = CaretContext.Normalize("Short one", "Short one and much more text");
        Assert.Equal("Short one", text);
        Assert.Equal(9, cursor);
    }

    [Fact]
    public void EmptyPrefixPutsCaretAtStart() =>
        Assert.Equal(0, CaretContext.Normalize("He have two cats. We are fine.", "").Cursor);

    [Fact]
    public void EmptyParagraph()
    {
        var (text, cursor) = CaretContext.Normalize("", "");
        Assert.Equal("", text);
        Assert.Equal(0, cursor);
        Assert.Null(SentenceExtractor.Sentence(text, cursor));
    }
}
