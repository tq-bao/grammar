using Grammar.Core.Engine;

namespace Grammar.Engine.Tests;

/// <summary>
/// Tìm model để test: <c>GRAMMAR_MODEL_PATH</c>, hoặc model mặc định trong GrammarApp/Resources/Models của repo
/// (thư mục model của bản macOS, tải bằng scripts/download-model.sh).
/// </summary>
internal static class TestModel
{
    public static readonly string? Path = Find();

    private static string? Find()
    {
        var env = Environment.GetEnvironmentVariable(ModelLocator.EnvironmentKey);
        if (!string.IsNullOrEmpty(env)) return File.Exists(env) ? env : null;
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var candidate = System.IO.Path.Combine(dir.FullName, "GrammarApp", "Resources", "Models", ModelLocator.DefaultModelFileName);
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }
}

/// <summary>Test cần model thật. Tự bỏ qua khi chưa có model.</summary>
public sealed class ModelFactAttribute : FactAttribute
{
    public ModelFactAttribute()
    {
        if (TestModel.Path is null)
            Skip = "Chưa có model: đặt GRAMMAR_MODEL_PATH hoặc chạy scripts/download-model.sh.";
    }
}

/// <summary>Nạp model một lần cho cả lớp test.</summary>
public sealed class EngineFixture : IDisposable
{
    private readonly Lazy<LlamaGrammarEngine> _engine =
        new(() => new LlamaGrammarEngine(TestModel.Path ?? throw new InvalidOperationException("Không có model")));

    public LlamaGrammarEngine Engine => _engine.Value;

    public void Dispose()
    {
        if (_engine.IsValueCreated) _engine.Value.Dispose();
    }
}
