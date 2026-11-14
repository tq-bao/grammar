using Grammar.Core.Engine;

namespace Grammar.Core.Tests;

public sealed class ModelLocatorTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "grammar-models-" + Guid.NewGuid().ToString("N"));
    private static readonly IReadOnlyDictionary<string, string?> NoEnv = new Dictionary<string, string?>();

    public ModelLocatorTests() => Directory.CreateDirectory(_dir);

    public void Dispose() => Directory.Delete(_dir, recursive: true);

    private string Touch(string name)
    {
        var path = Path.Combine(_dir, name);
        File.WriteAllText(path, "GGUF");
        return path;
    }

    [Fact]
    public void MissingModelReportsDefaultFileName()
    {
        // Spec grammar-correction (Windows), scenario "Thiếu thư mục model trên Windows".
        var e = Assert.Throws<GrammarEngineException>(() => ModelLocator.Locate(_dir, null, NoEnv));
        Assert.Equal(GrammarEngineErrorKind.ModelNotFound, e.Kind);
        Assert.Contains(ModelLocator.DefaultModelFileName, e.Message);
        Assert.Contains("Models", e.Message);
    }

    [Fact]
    public void MissingDirectoryReportsModelNotFound() =>
        Assert.Equal(GrammarEngineErrorKind.ModelNotFound,
            Assert.Throws<GrammarEngineException>(() => ModelLocator.Locate(Path.Combine(_dir, "nope"), null, NoEnv)).Kind);

    [Fact]
    public void FindsDefaultModel()
    {
        var path = Touch(ModelLocator.DefaultModelFileName);
        Assert.Equal(path, ModelLocator.Locate(_dir, null, NoEnv));
    }

    [Fact]
    public void SelectedModelWins()
    {
        // Spec grammar-correction (Windows), scenario "Chuyển sang model nhỏ hơn".
        Touch(ModelLocator.DefaultModelFileName);
        var small = Touch("Qwen2.5-3B-Instruct-Q4_K_M.gguf");
        Assert.Equal(small, ModelLocator.Locate(_dir, "Qwen2.5-3B-Instruct-Q4_K_M.gguf", NoEnv));
    }

    [Fact]
    public void DeletedSelectionFallsBackToDefault()
    {
        // Spec grammar-correction (Windows), scenario "File model đã chọn bị xoá".
        var path = Touch(ModelLocator.DefaultModelFileName);
        Assert.Equal(path, ModelLocator.Locate(_dir, "gone.gguf", NoEnv));
    }

    [Fact]
    public void SelectionCannotEscapeModelsDirectory()
    {
        var path = Touch(ModelLocator.DefaultModelFileName);
        Assert.Equal(path, ModelLocator.Locate(_dir, "../../etc/passwd", NoEnv));
    }

    [Fact]
    public void EnvironmentOverride()
    {
        var custom = Touch("custom.gguf");
        Assert.Equal(custom, ModelLocator.Locate(_dir, null, new Dictionary<string, string?> { [ModelLocator.EnvironmentKey] = custom }));
        var e = Assert.Throws<GrammarEngineException>(() =>
            ModelLocator.Locate(_dir, null, new Dictionary<string, string?> { [ModelLocator.EnvironmentKey] = "/nope.gguf" }));
        Assert.Equal(GrammarEngineErrorKind.ModelNotFound, e.Kind);
    }

    [Fact]
    public void ListsModelsWithDefaultFirst()
    {
        Touch("b.gguf");
        Touch(ModelLocator.DefaultModelFileName);
        Touch("a.gguf");
        Touch("notes.txt");
        Assert.Equal([ModelLocator.DefaultModelFileName, "a.gguf", "b.gguf"], ModelLocator.AvailableModels(_dir));
        Assert.Empty(ModelLocator.AvailableModels(Path.Combine(_dir, "missing")));
    }
}
