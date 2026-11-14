using Grammar.Core.Diff;
using Grammar.Core.Evaluation;

namespace Grammar.Core.Tests;

// Port của GrammarAppTests/GoldenSetTests.swift. Đọc thẳng file golden.json của bản macOS.
public class GoldenSetTests
{
    [Fact]
    public void ParsesAndHasBothKinds()
    {
        var set = GoldenSet.Load(RepoPaths.GoldenSet);
        Assert.True(set.Incorrect.Count >= 25);
        Assert.True(set.Correct.Count >= 15);
        Assert.True(set.Incorrect.Count + set.Correct.Count >= 50);
        foreach (var item in set.Incorrect)
        {
            Assert.NotEmpty(item.Expected);
            Assert.DoesNotContain(item.Input, item.Expected);
        }
    }

    [Fact]
    public void FindInRepoLocatesSharedFile() =>
        Assert.Equal(Path.GetFullPath(RepoPaths.GoldenSet), GoldenSet.FindInRepo(AppContext.BaseDirectory));

    [Fact]
    public void ReportMetrics()
    {
        var report = new EvaluationReport();
        report.Items.AddRange(
        [
            new("They was happy.", "They were happy.", ["They were happy."], EditVerdict.Accepted, 0.2),
            new("He go.", "He go.", ["He goes."], EditVerdict.Unchanged, 0.4),
            new("I am fine.", "I am fine.", null, EditVerdict.Unchanged, 0.1),
            new("I am ok.", "I'm doing okay today.", null, EditVerdict.Rewritten, 0.3),
        ]);
        Assert.Equal(0.5, report.MatchRate);
        Assert.Equal(0.5, report.KeepRate);
        Assert.Equal(0.25, report.RewriteRate);
        Assert.Equal(0.2, report.P50);
        Assert.Equal(0.4, report.P95);
    }
}
