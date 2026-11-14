using Grammar.Core.Diff;

namespace Grammar.Core.Tests;

// Port của GrammarAppTests/CorrectionNormalizerTests.swift.
public class CorrectionNormalizerTests
{
    private static string Reconcile(string original, string corrected) =>
        CorrectionNormalizer.Reconcile(original, corrected);

    [Fact]
    public void KeepsUserCapitalizationAndNoFinalPeriod() =>
        Assert.Equal("yesterday i went to the office",
            Reconcile("yesterday i go to the office", "Yesterday I went to the office."));

    [Fact]
    public void KeepsUserFinalPunctuation()
    {
        Assert.Equal("She went to school yesterday,",
            Reconcile("She go to school yesterday,", "She went to school yesterday."));
        Assert.Equal("where is he going", Reconcile("where is he going", "Where is he going?"));
        Assert.Equal("They were happy!!", Reconcile("They was happy!!", "They were happy."));
    }

    [Fact]
    public void OnlyCaseAndFinalPunctuationDifferenceReturnsOriginal()
    {
        const string original = "thanks, will check it tonight";
        Assert.Equal(original, Reconcile(original, "Thanks, will check it tonight."));
        Assert.Equal("i will call you after lunch.",
            Reconcile("i will call you after lunch.", "I will call you after lunch."));
    }

    [Fact]
    public void RealFixesAreKeptAlongsideCaseDifferences() =>
        Assert.Equal("he has two cats and they are cute",
            Reconcile("he have two cats and they is cute", "He has two cats and they are cute."));

    [Fact]
    public void MidSentenceCommaIsStillChecked() =>
        // Dấu phẩy ở giữa câu vẫn là một chỉnh sửa.
        Assert.Equal("ok, I'll ping Minh about it",
            Reconcile("ok I'll ping Minh about it", "Ok, I'll ping Minh about it."));

    [Fact]
    public void InsertedWordKeepsModelText() =>
        Assert.Equal("i am going home now.", Reconcile("i going home now.", "I am going home now."));

    [Fact]
    public void DiffAfterReconcileIsIdentical()
    {
        var corrected = Reconcile("thanks, will check it tonight", "Thanks, will check it tonight.");
        Assert.True(new WordDiff("thanks, will check it tonight", corrected).IsIdentical);
    }

    [Fact]
    public void PunctuationOnlyInputs()
    {
        Assert.Equal("...", Reconcile("...", "..."));
        Assert.Equal("hello there", Reconcile("hello there", "."));
    }
}

// Port của GrammarAppTests/DiffHighlighterTests.swift. Bản Swift kiểm tra AttributedString;
// ở đây kiểm tra danh sách đoạn có kiểu mà WPF dùng để dựng Run.
public class DiffHighlighterTests
{
    private static List<string> Segments(IReadOnlyList<StyledSegment> segments, SegmentStyle style) =>
        segments.Where(s => s.Style == style).Select(s => s.Text).ToList();

    [Fact]
    public void ReplacedWordIsUnderlinedAndFixIsHighlighted()
    {
        var h = DiffHighlighter.Highlights(new WordDiff("He have two cats.", "He has two cats."));
        Assert.Equal([new TextSpan(3, 4)], h.Underlines);  // "have"
        Assert.Equal([new TextSpan(3, 3)], h.Insertions);  // "has"
        Assert.Empty(h.Gaps);
    }

    [Fact]
    public void MissingWordMarksTheGapBetweenWords()
    {
        var h = DiffHighlighter.Highlights(new WordDiff("I going home.", "I am going home."));
        Assert.Empty(h.Underlines);
        Assert.Equal([new TextSpan(1, 1)], h.Gaps);  // khoảng trắng giữa "I" và "going"
    }

    [Fact]
    public void OriginalTextUnderlinesWrongWord()
    {
        var segments = DiffHighlighter.OriginalSegments(new WordDiff("He have two cats.", "He has two cats."));
        Assert.Equal("He have two cats.", string.Concat(segments.Select(s => s.Text)));
        Assert.Equal(["have"], Segments(segments, SegmentStyle.Error));
    }

    [Fact]
    public void OriginalTextMarksMissingWordGap()
    {
        var segments = DiffHighlighter.OriginalSegments(new WordDiff("I going home.", "I am going home."));
        Assert.Equal([" "], Segments(segments, SegmentStyle.Gap));
        Assert.Empty(Segments(segments, SegmentStyle.Error));
    }

    [Fact]
    public void GapAtEndMarksLastCharacter()
    {
        var segments = DiffHighlighter.OriginalSegments(new WordDiff("I am going", "I am going home"));
        Assert.Equal(["g"], Segments(segments, SegmentStyle.Gap));
    }

    [Fact]
    public void CorrectedTextHighlightsInsertedWords()
    {
        var segments = DiffHighlighter.CorrectedSegments(new WordDiff("He have two cats.", "He has two cats."));
        Assert.Equal("He has two cats.", string.Concat(segments.Select(s => s.Text)));
        Assert.Equal(["has"], Segments(segments, SegmentStyle.Fix));
    }

    [Fact]
    public void IdenticalSentenceHasNoHighlights()
    {
        var diff = new WordDiff("I am fine.", "I am fine.");
        Assert.Equal([new StyledSegment("I am fine.", SegmentStyle.Plain)], DiffHighlighter.OriginalSegments(diff));
        Assert.Equal([new StyledSegment("I am fine.", SegmentStyle.Plain)], DiffHighlighter.CorrectedSegments(diff));
    }

    [Fact]
    public void SpecExamples()
    {
        // Spec checker-window: "He have" -> "He has", "I going" -> "I am going".
        var replaced = new WordDiff("He have two cats.", "He has two cats.");
        Assert.Equal(["He ", "have", " two cats."], DiffHighlighter.OriginalSegments(replaced).Select(s => s.Text));
        var missing = new WordDiff("I going home.", "I am going home.");
        Assert.Equal(["I", " ", "going home."], DiffHighlighter.OriginalSegments(missing).Select(s => s.Text));
        Assert.Equal(["I ", "am", " going home."], DiffHighlighter.CorrectedSegments(missing).Select(s => s.Text));
    }
}
