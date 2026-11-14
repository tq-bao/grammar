namespace Grammar.Core.Engine;

/// <summary>
/// Tìm file model GGUF. Port của GrammarKit/Engine/ModelLocator.swift: bản macOS tìm trong app bundle,
/// bản Windows tìm trong thư mục <c>Models</c> cạnh <c>Grammar.exe</c> và cho chọn model trong Cài đặt.
/// </summary>
public static class ModelLocator
{
    /// <summary>Model mặc định, chọn theo kết quả GrammarBench (xem docs/model-benchmark.md). Giống bản macOS.</summary>
    public const string DefaultModelFileName = "Qwen2.5-7B-Instruct-Q4_K_M.gguf";

    /// <summary>Thư mục chứa model, nằm cạnh file chạy của app.</summary>
    public const string ModelsDirectoryName = "Models";

    /// <summary>Biến môi trường để chỉ định đường dẫn model khi dev/benchmark.</summary>
    public const string EnvironmentKey = "GRAMMAR_MODEL_PATH";

    /// <summary>Thư mục <c>Models</c> cạnh file chạy.</summary>
    public static string DefaultModelsDirectory => Path.Combine(AppContext.BaseDirectory, ModelsDirectoryName);

    /// <summary>
    /// Đường dẫn model theo thứ tự: <see cref="EnvironmentKey"/>, model đã chọn trong Cài đặt (nếu file còn),
    /// rồi model mặc định trong <paramref name="modelsDirectory"/>.
    /// </summary>
    /// <exception cref="GrammarEngineException">Không tìm thấy model nào (<see cref="GrammarEngineErrorKind.ModelNotFound"/>).</exception>
    public static string Locate(string modelsDirectory, string? selectedModel = null, IReadOnlyDictionary<string, string?>? environment = null)
    {
        var overridePath = environment is null
            ? Environment.GetEnvironmentVariable(EnvironmentKey)
            : environment.GetValueOrDefault(EnvironmentKey);
        if (!string.IsNullOrEmpty(overridePath))
        {
            return File.Exists(overridePath)
                ? overridePath
                : throw new GrammarEngineException(GrammarEngineErrorKind.ModelNotFound, overridePath);
        }

        // Chỉ nhận tên file (không nhận đường dẫn) để lựa chọn luôn nằm trong thư mục Models.
        if (!string.IsNullOrWhiteSpace(selectedModel) && selectedModel == Path.GetFileName(selectedModel))
        {
            var selected = Path.Combine(modelsDirectory, selectedModel);
            if (File.Exists(selected)) return selected;
        }

        var fallback = Path.Combine(modelsDirectory, DefaultModelFileName);
        if (File.Exists(fallback)) return fallback;

        throw new GrammarEngineException(GrammarEngineErrorKind.ModelNotFound, DefaultModelFileName);
    }

    /// <summary>Tên các file <c>*.gguf</c> trong thư mục model, model mặc định đứng đầu.</summary>
    public static IReadOnlyList<string> AvailableModels(string modelsDirectory)
    {
        if (!Directory.Exists(modelsDirectory)) return [];
        return Directory.EnumerateFiles(modelsDirectory, "*.gguf")
            .Select(Path.GetFileName)
            .OfType<string>()
            .OrderBy(name => name == DefaultModelFileName ? 0 : 1)
            .ThenBy(name => name, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}
