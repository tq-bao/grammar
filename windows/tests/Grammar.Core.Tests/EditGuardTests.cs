using Grammar.Core.Diff;

namespace Grammar.Core.Tests;

// Port của EditGuardTests trong GrammarAppTests/DiffTests.swift.
public class EditGuardTests
{
    private readonly EditGuard _guard = new();

    [Fact]
    public void ShortSentenceWithSeveralWordFormFixesIsAccepted()
    {
        // Spec grammar-correction, scenario "Câu ngắn có nhiều lỗi dạng từ" và "Sửa trợ động từ và chính tả".
        Assert.Equal(EditVerdict.Accepted,
            _guard.Evaluate(new WordDiff("I'm collect more envidences", "I'm collecting more evidence")));
        Assert.Equal(EditVerdict.Accepted,
            _guard.Evaluate(new WordDiff("She dont has any monies", "She doesn't have any money")));
    }

    [Fact]
    public void AlmostEverythingChangedIsRejectedEvenIfSimilar() =>
        // 5/5 token đổi (dù đều "gần giống"): vượt mức chặn phụ 80%.
        Assert.Equal(EditVerdict.Rewritten,
            _guard.Evaluate(new WordDiff("Me want eat many food", "Mo wants eats more foods")));

    [Fact]
    public void SingleWordFixIsAccepted() =>
        Assert.Equal(EditVerdict.Accepted,
            _guard.Evaluate(new WordDiff("She go to school yesterday.", "She went to school yesterday.")));

    [Fact]
    public void IdenticalIsUnchanged() =>
        Assert.Equal(EditVerdict.Unchanged,
            _guard.Evaluate(new WordDiff("I have finished the report.", "I have finished the report.")));

    [Fact]
    public void FullRewriteIsRejected() =>
        Assert.Equal(EditVerdict.Rewritten, _guard.Evaluate(new WordDiff(
            "gonna send u the file tmr, it have the numbers",
            "I will send you the document tomorrow; it contains the figures.")));

    [Fact]
    public void SplittingIntoTwoSentencesIsRejected() =>
        Assert.Equal(EditVerdict.Rewritten, _guard.Evaluate(new WordDiff(
            "I went home and I was tired and I slept early",
            "I went home and I was tired. I slept early.")));
}
