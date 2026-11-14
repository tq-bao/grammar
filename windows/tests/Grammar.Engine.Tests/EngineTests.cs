using Grammar.Core.Engine;

namespace Grammar.Engine.Tests;

// Port của LlamaEngineIntegrationTests (GrammarAppTests/EngineTests.swift).
public class LlamaEngineIntegrationTests(EngineFixture fixture) : IClassFixture<EngineFixture>
{
    [ModelFact]
    public async Task CorrectsSubjectVerbAgreementOffline()
    {
        // Spec grammar-correction, scenario "Không có mạng".
        Assert.Equal("They were happy.", await fixture.Engine.CorrectAsync("They was happy."));
    }

    [ModelFact]
    public async Task CorrectSentenceIsUnchanged() =>
        Assert.Equal("I have finished the report.", await fixture.Engine.CorrectAsync("I have finished the report."));

    [ModelFact]
    public async Task RepeatedCallsReuseKvCacheAndStayCorrect()
    {
        // Prefix cố định được giữ trong KV cache; câu sau không được dính phần còn lại của câu trước.
        Assert.Equal("He has two cats.", await fixture.Engine.CorrectAsync("He have two cats."));
        Assert.Equal("They were happy.", await fixture.Engine.CorrectAsync("They was happy."));
        Assert.Equal("He has two cats.", await fixture.Engine.CorrectAsync("He have two cats."));
    }

    [ModelFact]
    public async Task ConcurrentCallsAreSerialized()
    {
        var a = fixture.Engine.CorrectAsync("They was happy.");
        var b = fixture.Engine.CorrectAsync("He have two cats.");
        Assert.Equal(["They were happy.", "He has two cats."], await Task.WhenAll(a, b));
    }

    [ModelFact]
    public async Task CancelledCallThrowsAndEngineStillWorks()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => fixture.Engine.CorrectAsync("They was happy.", cts.Token));
        Assert.Equal("They were happy.", await fixture.Engine.CorrectAsync("They was happy."));
    }

    [ModelFact]
    public void ReportsGpuOnAppleSilicon()
    {
        // Trên Mac, LLamaSharp dùng Metal; trên Windows là Vulkan nếu có GPU.
        if (OperatingSystem.IsMacOS()) Assert.Equal(ComputeBackend.Gpu, fixture.Engine.Backend);
        Assert.True(fixture.Engine.OffloadedLayers >= 0);
    }
}

public class EngineErrorTests
{
    [Fact]
    public void MissingModelFileThrowsClearError()
    {
        var e = Assert.Throws<GrammarEngineException>(() => new LlamaGrammarEngine("/nonexistent/model.gguf"));
        Assert.Equal(GrammarEngineErrorKind.ModelLoadFailed, e.Kind);
        Assert.Equal("/nonexistent/model.gguf", e.Detail);
    }

    [Fact]
    public void ParsesOffloadedLayersFromLog()
    {
        Assert.Equal(29, NativeBackend.OffloadedLayers("load_tensors: offloaded 29/29 layers to GPU\n"));
        Assert.Equal(0, NativeBackend.OffloadedLayers("load_tensors: offloaded 0/29 layers to GPU"));
        Assert.Null(NativeBackend.OffloadedLayers("load_tensors: CPU model buffer size = 4400 MiB"));
    }
}
