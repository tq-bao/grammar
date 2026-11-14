using Grammar.Core.Engine;

namespace Grammar.Engine;

/// <summary>Kết quả nạp model: engine, phần cứng đang dùng, và lý do phải chuyển sang CPU (nếu có).</summary>
public sealed record LoadedEngine(LlamaGrammarEngine Engine, ComputeBackend Backend, string? GpuFallbackReason);

/// <summary>
/// Nạp model, ưu tiên GPU. Không có GPU dùng được, hoặc nạp/warm-up trên GPU lỗi (ví dụ thiếu VRAM),
/// thì giải phóng và nạp lại để chạy bằng CPU. Xem design.md §5 và spec grammar-correction
/// ("Tự chọn phần cứng chạy mô hình trên Windows").
/// </summary>
public static class BackendSelector
{
    /// <summary>Số layer đưa lên GPU: số lớn = toàn bộ.</summary>
    public const int AllLayers = 999;

    public static async Task<LoadedEngine> LoadAsync(string modelPath, CancellationToken cancellationToken = default)
    {
        var (engine, fallback) = await LoadAsync(
            gpuAvailable: NativeBackend.SupportsGpuOffload,
            create: layers => new LlamaGrammarEngine(modelPath, new LlamaGrammarEngine.Configuration { GpuLayers = layers }),
            warmUp: e => e.WarmUpAsync(cancellationToken),
            cancellationToken);
        return new LoadedEngine(engine, engine.Backend, fallback);
    }

    /// <summary>Logic chọn phần cứng, tách khỏi engine thật để test được.</summary>
    /// <param name="gpuAvailable">Thư viện native hỗ trợ đưa layer lên GPU.</param>
    /// <param name="create">Tạo engine với số layer trên GPU cho trước (0 = chỉ CPU).</param>
    /// <param name="warmUp">Chạy thử một câu. Lỗi ở đây trên GPU cũng dẫn tới chuyển sang CPU.</param>
    /// <returns>Engine đã warm-up, và lý do chuyển sang CPU nếu đã thử GPU mà lỗi.</returns>
    internal static async Task<(TEngine Engine, string? GpuFallbackReason)> LoadAsync<TEngine>(
        bool gpuAvailable,
        Func<int, TEngine> create,
        Func<TEngine, Task> warmUp,
        CancellationToken cancellationToken)
        where TEngine : class, IDisposable
    {
        string? fallbackReason = null;
        if (gpuAvailable)
        {
            TEngine? gpu = null;
            try
            {
                gpu = create(AllLayers);
                await warmUp(gpu);
                return (gpu, null);
            }
            catch (OperationCanceledException)
            {
                gpu?.Dispose();
                throw;
            }
            catch (GrammarEngineException e) when (e.Kind == GrammarEngineErrorKind.ModelLoadFailed && !File.Exists(e.Detail ?? ""))
            {
                // File model không tồn tại: chạy CPU cũng không khác gì, báo lỗi luôn.
                gpu?.Dispose();
                throw;
            }
            catch (Exception e)
            {
                gpu?.Dispose();
                fallbackReason = e.Message;
            }
        }

        cancellationToken.ThrowIfCancellationRequested();
        var cpu = create(0);
        try
        {
            await warmUp(cpu);
        }
        catch
        {
            cpu.Dispose();
            throw;
        }
        return (cpu, fallbackReason);
    }
}
