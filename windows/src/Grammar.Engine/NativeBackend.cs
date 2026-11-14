using System.Text;
using System.Text.RegularExpressions;
using LLama.Native;

namespace Grammar.Engine;

/// <summary>
/// Cấu hình nạp thư viện native của llama.cpp (qua LLamaSharp) và đọc log của nó.
/// </summary>
/// <remarks>
/// LLamaSharp chỉ nạp một bộ thư viện native cho cả tiến trình, nên phải cấu hình trước lời gọi native đầu tiên.
/// Trên Windows: ưu tiên bộ Vulkan (GPU NVIDIA/AMD/Intel). Máy không có driver Vulkan thì LLamaSharp tự chuyển sang
/// bộ CPU hợp với mức AVX của máy. Bộ Vulkan dùng chung <c>ggml-cpu.dll</c> của bộ CPU, nên vẫn chạy được bằng CPU
/// khi không đưa layer nào lên GPU.
/// </remarks>
internal static partial class NativeBackend
{
    private static readonly Lock Gate = new();
    /// <summary>Xếp hàng các lần nạp model: log của hai lần nạp không lẫn vào nhau, và không nạp hai model cùng lúc.</summary>
    private static readonly Lock LoadGate = new();
    private static bool _configured;
    private static StringBuilder? _capture;

    public static void EnsureConfigured()
    {
        lock (Gate)
        {
            if (_configured) return;
            _configured = true;
            // Chỉ app này cấu hình LLamaSharp, và cấu hình đúng một lần trước lời gọi native đầu tiên.
            NativeLibraryConfig.All
                .WithCuda(false)
                .WithVulkan(true)
                .WithAutoFallback(true)
                .WithLogCallback(OnLog);
            // Gọi một hàm native để nạp thư viện ngay, rồi chuyển log của llama.cpp về đây (mặc định in ra console).
            NativeLogConfig.llama_log_set(OnLog);
        }
    }

    /// <summary>Thư viện đã nạp hỗ trợ đưa layer lên GPU (Vulkan trên Windows, Metal trên Mac).</summary>
    public static bool SupportsGpuOffload
    {
        get
        {
            EnsureConfigured();
            return NativeApi.llama_supports_gpu_offload();
        }
    }

    /// <summary>Chạy <paramref name="action"/> (nạp model) và trả về log llama.cpp in ra trong lúc đó.</summary>
    public static (T Result, string Log) Capture<T>(Func<T> action)
    {
        lock (LoadGate)
        {
            var capture = new StringBuilder();
            lock (Gate) _capture = capture;
            try
            {
                var result = action();
                lock (Gate) return (result, capture.ToString());
            }
            finally
            {
                lock (Gate) _capture = null;
            }
        }
    }

    /// <summary>Số layer được đưa lên GPU, đọc từ dòng log "offloaded N/M layers to GPU" của llama.cpp.</summary>
    public static int? OffloadedLayers(string log)
    {
        var match = OffloadedRegex().Match(log);
        return match.Success ? int.Parse(match.Groups[1].Value) : null;
    }

    private static void OnLog(LLamaLogLevel level, string message)
    {
        lock (Gate) _capture?.Append(message);
    }

    [GeneratedRegex(@"offloaded (\d+)/(\d+) layers to GPU")]
    private static partial Regex OffloadedRegex();
}
