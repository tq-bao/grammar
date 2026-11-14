using Grammar.Core.Engine;

namespace Grammar.Engine.Tests;

/// <summary>Spec grammar-correction (Windows): "Tự chọn phần cứng chạy mô hình trên Windows".</summary>
public class BackendSelectorTests
{
    private sealed class FakeEngine(int layers) : IDisposable
    {
        public int Layers { get; } = layers;
        public bool Disposed { get; private set; }
        public void Dispose() => Disposed = true;
    }

    private static readonly List<FakeEngine> Created = [];

    private static FakeEngine Create(int layers, bool failGpu = false)
    {
        if (failGpu && layers > 0) throw new GrammarEngineException(GrammarEngineErrorKind.ContextCreationFailed);
        var e = new FakeEngine(layers);
        lock (Created) Created.Add(e);
        return e;
    }

    [Fact]
    public async Task UsesGpuWhenAvailable()
    {
        var (engine, reason) = await BackendSelector.LoadAsync(true, l => Create(l), _ => Task.CompletedTask, default);
        Assert.Equal(BackendSelector.AllLayers, engine.Layers);
        Assert.Null(reason);
    }

    [Fact]
    public async Task NoGpuGoesStraightToCpu()
    {
        var (engine, reason) = await BackendSelector.LoadAsync(false, l => Create(l), _ => Task.CompletedTask, default);
        Assert.Equal(0, engine.Layers);
        Assert.Null(reason);
    }

    [Fact]
    public async Task GpuLoadFailureFallsBackToCpu()
    {
        // Scenario "Máy không có GPU dùng được": nạp model lên GPU thất bại.
        var (engine, reason) = await BackendSelector.LoadAsync(true, l => Create(l, failGpu: true), _ => Task.CompletedTask, default);
        Assert.Equal(0, engine.Layers);
        Assert.NotNull(reason);
    }

    [Fact]
    public async Task GpuWarmUpFailureDisposesGpuEngineAndFallsBack()
    {
        FakeEngine? gpu = null;
        var (engine, reason) = await BackendSelector.LoadAsync(
            true,
            l => { var e = Create(l); if (l > 0) gpu = e; return e; },
            e => e.Layers > 0 ? throw new InvalidOperationException("out of VRAM") : Task.CompletedTask,
            default);
        Assert.Equal(0, engine.Layers);
        Assert.True(gpu!.Disposed);
        Assert.Equal("out of VRAM", reason);
    }

    [Fact]
    public async Task CpuFailureIsReported()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => BackendSelector.LoadAsync<FakeEngine>(
            false, _ => throw new InvalidOperationException("broken"), _ => Task.CompletedTask, default));
    }

    [Fact]
    public async Task MissingFileDoesNotRetryOnCpu()
    {
        var attempts = 0;
        await Assert.ThrowsAsync<GrammarEngineException>(() => BackendSelector.LoadAsync<FakeEngine>(
            true,
            _ => { attempts++; throw new GrammarEngineException(GrammarEngineErrorKind.ModelLoadFailed, "/nope.gguf"); },
            _ => Task.CompletedTask,
            default));
        Assert.Equal(1, attempts);
    }
}

public class BackendSelectorIntegrationTests
{
    [ModelFact]
    public async Task LoadsRealModelAndReportsBackend()
    {
        var loaded = await BackendSelector.LoadAsync(TestModel.Path!);
        using var engine = loaded.Engine;
        if (OperatingSystem.IsMacOS()) Assert.Equal(ComputeBackend.Gpu, loaded.Backend);
        Assert.Equal("They were happy.", await engine.CorrectAsync("They was happy."));
    }

    [ModelFact]
    public async Task CpuOnlyEngineWorks()
    {
        // Chạy hẳn bằng CPU (0 layer trên GPU), như máy Windows không có GPU.
        using var engine = new LlamaGrammarEngine(TestModel.Path!, new LlamaGrammarEngine.Configuration { GpuLayers = 0 });
        Assert.Equal(ComputeBackend.Cpu, engine.Backend);
        Assert.Equal("They were happy.", await engine.CorrectAsync("They was happy."));
    }
}
