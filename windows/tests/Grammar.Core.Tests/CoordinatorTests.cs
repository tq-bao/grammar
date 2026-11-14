using Grammar.Core.Engine;
using Grammar.Core.Pipeline;
using Microsoft.Extensions.Time.Testing;

namespace Grammar.Core.Tests;

// Port của ResultCacheTests (GrammarAppTests/PipelineTests.swift).
public class ResultCacheTests
{
    [Fact]
    public void HitWithNormalizedWhitespace()
    {
        var cache = new ResultCache<string>(2);
        cache.Insert("x", "He  have cats ");
        Assert.True(cache.TryGetValue("He have cats", out var value));
        Assert.Equal("x", value);
    }

    [Fact]
    public void EvictsLeastRecentlyUsed()
    {
        var cache = new ResultCache<int>(2);
        cache.Insert(1, "a");
        cache.Insert(2, "b");
        cache.TryGetValue("a", out _);  // "a" mới dùng, "b" thành cũ nhất
        cache.Insert(3, "c");
        Assert.Equal(2, cache.Count);
        Assert.False(cache.TryGetValue("b", out _));
        Assert.True(cache.TryGetValue("a", out var a));
        Assert.Equal(1, a);
        Assert.True(cache.TryGetValue("c", out var c));
        Assert.Equal(3, c);
    }

    [Fact]
    public void ReinsertUpdatesValue()
    {
        var cache = new ResultCache<int>(2);
        cache.Insert(1, "a");
        cache.Insert(2, "a");
        Assert.Equal(1, cache.Count);
        Assert.True(cache.TryGetValue("a", out var v));
        Assert.Equal(2, v);
    }
}

// Port của CheckCoordinatorTests (GrammarAppTests/PipelineTests.swift). Thời gian giả lập bằng FakeTimeProvider.
public class CheckCoordinatorTests
{
    private static readonly TimeSpan Debounce = TimeSpan.FromMilliseconds(700);

    private static (CheckCoordinator, FakeEngine, FakeTimeProvider) Make(Dictionary<string, string>? answers = null)
    {
        var engine = new FakeEngine(answers ?? []);
        var time = new FakeTimeProvider();
        return (new CheckCoordinator(engine, debounce: Debounce, timeProvider: time), engine, time);
    }

    [Fact]
    public void CorrectsAfterDebounce() => UiThread.Run(async () =>
    {
        var (c, _, time) = Make(new() { ["She go to school yesterday."] = "She went to school yesterday." });
        c.Submit("She go to school yesterday.", TextSource.FocusedField);
        time.Advance(Debounce);
        await c.WaitForPendingCheckAsync();
        var corrected = Assert.IsType<CheckState.Corrected>(c.State);
        Assert.Equal(["go"], corrected.Diff.RemovedWords);
        Assert.Equal("She went to school yesterday.", corrected.Diff.Corrected);
    });

    [Fact]
    public void TypingContinuouslyDoesNotCallEngine() => UiThread.Run(async () =>
    {
        // Spec grammar-correction, scenario "Đang gõ liên tục".
        var (c, engine, time) = Make();
        foreach (var partial in new[] { "She go", "She go to", "She go to school", "She go to school today" })
        {
            c.Submit(partial, TextSource.FocusedField);
            time.Advance(TimeSpan.FromMilliseconds(300));
            await UiThread.Pump();
        }
        Assert.Empty(engine.Calls);
        time.Advance(Debounce);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(["She go to school today"], engine.Calls);
    });

    [Fact]
    public void StaleResultIsDropped() => UiThread.Run(async () =>
    {
        // Spec grammar-correction, scenario "Câu thay đổi khi đang kiểm tra".
        var (c, engine, time) = Make(new()
        {
            ["They was happy today."] = "They were happy today.",
            ["We is ready now."] = "We are ready now.",
        });
        engine.Hold = true;
        c.Submit("They was happy today.", TextSource.FocusedField);
        time.Advance(Debounce);
        await UiThread.Pump();
        Assert.Equal(["They was happy today."], engine.Calls);  // engine đang chạy câu 1

        c.Submit("We is ready now.", TextSource.FocusedField);
        engine.Release("They was happy today.");                // câu 1 xong, nhưng không được hiển thị
        await UiThread.Pump();
        Assert.IsNotType<CheckState.Corrected>(c.State);

        time.Advance(Debounce);
        await UiThread.Pump();
        engine.Release("We is ready now.");
        await c.WaitForPendingCheckAsync();
        var corrected = Assert.IsType<CheckState.Corrected>(c.State);
        Assert.Equal("We is ready now.", corrected.Diff.Original);
    });

    [Fact]
    public void CacheHitSkipsEngine() => UiThread.Run(async () =>
    {
        // Spec grammar-correction, scenario "Câu lặp lại".
        var (c, _, _) = Make(new() { ["They was happy today."] = "They were happy today." });
        c.Submit("They was happy today.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        c.Submit("We are fine here.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        c.Submit("They was happy today.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(2, c.EngineCallCount);
        Assert.IsType<CheckState.Corrected>(c.State);
    });

    [Fact]
    public void CorrectSentenceIsOk() => UiThread.Run(async () =>
    {
        var (c, _, _) = Make();
        c.Submit("I have finished the report.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(new CheckState.Ok("I have finished the report."), c.State);
    });

    [Fact]
    public void CaseAndFinalPunctuationDifferencesAreOk() => UiThread.Run(async () =>
    {
        var (c, _, _) = Make(new() { ["thanks, will check it tonight"] = "Thanks, will check it tonight." });
        c.Submit("thanks, will check it tonight", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(new CheckState.Ok("thanks, will check it tonight"), c.State);
    });

    [Fact]
    public void RealFixKeepsUserCapitalization() => UiThread.Run(async () =>
    {
        var (c, _, _) = Make(new() { ["yesterday i go to the office"] = "Yesterday I went to the office." });
        c.Submit("yesterday i go to the office", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        var corrected = Assert.IsType<CheckState.Corrected>(c.State);
        Assert.Equal("yesterday i went to the office", corrected.Diff.Corrected);
        Assert.Equal(["go"], corrected.Diff.RemovedWords);
    });

    [Fact]
    public void VietnameseIsNotChecked() => UiThread.Run(async () =>
    {
        var (c, _, _) = Make();
        c.Submit("Hôm nay tôi đi học muộn.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(new CheckState.NotEnglish("Hôm nay tôi đi học muộn."), c.State);
        Assert.Equal(0, c.EngineCallCount);
    });

    [Fact]
    public void RewriteIsUncertain() => UiThread.Run(async () =>
    {
        const string original = "gonna send u the file tmr, it have the numbers";
        var (c, _, _) = Make(new() { [original] = "I will send you the document tomorrow; it contains the figures." });
        c.Submit(original, TextSource.Manual, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(new CheckState.Uncertain(original), c.State);
    });

    [Fact]
    public void PausedIgnoresFocusedFieldButNotManual() => UiThread.Run(async () =>
    {
        var (c, _, _) = Make();
        c.IsPaused = true;
        c.Submit("I have finished the report.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(CheckState.IdleState, c.State);
        c.Submit("I have finished the report.", TextSource.Manual, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(new CheckState.Ok("I have finished the report."), c.State);
    });

    [Fact]
    public void EngineErrorIsShown() => UiThread.Run(async () =>
    {
        var c = new CheckCoordinator(engine: null, debounce: TimeSpan.FromMilliseconds(10));
        Assert.Equal(CheckState.LoadingModelState, c.State);
        c.SetEngineError("Không tìm thấy model");
        c.Submit("They was happy today.", TextSource.Manual, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(new CheckState.ModelError("Không tìm thấy model"), c.State);
    });

    // Thêm cho bản Windows.

    [Fact]
    public void EngineExceptionBecomesModelError() => UiThread.Run(async () =>
    {
        var (c, engine, _) = Make();
        engine.Throw = new GrammarEngineException(GrammarEngineErrorKind.DecodeFailed, "-1");
        c.Submit("They was happy today.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        var error = Assert.IsType<CheckState.ModelError>(c.State);
        Assert.Contains("-1", error.Message);
    });

    [Fact]
    public void SentenceTypedWhileLoadingIsCheckedWhenEngineArrives() => UiThread.Run(async () =>
    {
        var c = new CheckCoordinator(engine: null, debounce: TimeSpan.Zero);
        c.Submit("They was happy today.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Equal(CheckState.LoadingModelState, c.State);

        c.SetEngine(new FakeEngine(new() { ["They was happy today."] = "They were happy today." }));
        await c.WaitForPendingCheckAsync();
        Assert.IsType<CheckState.Corrected>(c.State);
    });

    [Fact]
    public void BeginLoadingModelShowsLoadingUntilNewEngine() => UiThread.Run(async () =>
    {
        // Spec grammar-correction (Windows), scenario "Chuyển sang model nhỏ hơn": panel báo đang nạp model.
        var (c, _, _) = Make();
        c.Submit("I have finished the report.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        c.BeginLoadingModel();
        Assert.Equal(CheckState.LoadingModelState, c.State);
        c.SetEngine(new FakeEngine([]));
        await c.WaitForPendingCheckAsync();
        Assert.Equal(new CheckState.Ok("I have finished the report."), c.State);
    });

    [Fact]
    public void RaisesPropertyChanged() => UiThread.Run(async () =>
    {
        var (c, _, _) = Make();
        var changed = new List<string?>();
        c.PropertyChanged += (_, e) => changed.Add(e.PropertyName);
        c.Submit("I have finished the report.", TextSource.FocusedField, immediately: true);
        await c.WaitForPendingCheckAsync();
        Assert.Contains(nameof(CheckCoordinator.Sentence), changed);
        Assert.Contains(nameof(CheckCoordinator.State), changed);
    });
}
