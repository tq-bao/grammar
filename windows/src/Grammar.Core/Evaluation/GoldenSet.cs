using System.Text.Json;
using System.Text.Json.Serialization;
using Grammar.Core.Diff;
using Grammar.Core.Pipeline;

namespace Grammar.Core.Evaluation;

/// <summary>
/// Bộ câu đánh giá model. Dùng chung file với bản macOS: GrammarAppTests/Fixtures/golden.json.
/// Port của GrammarKit/Evaluation/GoldenSet.swift.
/// </summary>
public sealed record GoldenSet(
    [property: JsonPropertyName("incorrect")] IReadOnlyList<GoldenSet.IncorrectItem> Incorrect,
    [property: JsonPropertyName("correct")] IReadOnlyList<string> Correct)
{
    /// <param name="Expected">Các đáp án được chấp nhận.</param>
    public sealed record IncorrectItem(
        [property: JsonPropertyName("category")] string Category,
        [property: JsonPropertyName("input")] string Input,
        [property: JsonPropertyName("expected")] IReadOnlyList<string> Expected);

    public static GoldenSet Load(string path) =>
        JsonSerializer.Deserialize<GoldenSet>(File.ReadAllText(path))
        ?? throw new InvalidDataException($"Golden set rỗng: {path}");

    /// <summary>
    /// Tìm golden.json của repo: đi ngược lên từ <paramref name="start"/> tới thư mục có GrammarAppTests/Fixtures/golden.json.
    /// </summary>
    public static string? FindInRepo(string start)
    {
        for (var dir = new DirectoryInfo(start); dir is not null; dir = dir.Parent)
        {
            var path = Path.Combine(dir.FullName, "GrammarAppTests", "Fixtures", "golden.json");
            if (File.Exists(path)) return path;
        }
        return null;
    }
}

/// <summary>Kết quả chấm một model trên golden set.</summary>
public sealed class EvaluationReport
{
    /// <param name="Expected"><c>null</c> = câu đúng, phải giữ nguyên.</param>
    public sealed record Item(string Input, string Output, IReadOnlyList<string>? Expected, EditVerdict Verdict, double Seconds)
    {
        public bool Passed
        {
            get
            {
                var output = ResultCache<int>.Normalize(Output);
                if (Expected is { } expected)
                {
                    // Đáp án cũng được đối chiếu với câu gốc như kết quả (bỏ qua hoa thường, dấu cuối câu).
                    return expected.Any(e => ResultCache<int>.Normalize(CorrectionNormalizer.Reconcile(Input, e)) == output);
                }
                return output == ResultCache<int>.Normalize(Input);
            }
        }
    }

    public List<Item> Items { get; } = [];

    private IEnumerable<Item> CorrectItems => Items.Where(i => i.Expected is null);
    private IEnumerable<Item> IncorrectItems => Items.Where(i => i.Expected is not null);

    /// <summary>Tỉ lệ câu đúng được giữ nguyên.</summary>
    public double KeepRate => Rate(CorrectItems.Count(i => i.Passed), CorrectItems.Count());
    /// <summary>Tỉ lệ câu sai được sửa khớp đáp án.</summary>
    public double MatchRate => Rate(IncorrectItems.Count(i => i.Passed), IncorrectItems.Count());
    /// <summary>Tỉ lệ kết quả bị EditGuard loại vì viết lại câu.</summary>
    public double RewriteRate => Rate(Items.Count(i => i.Verdict == EditVerdict.Rewritten), Items.Count);

    public double P50 => Percentile(0.5);
    public double P95 => Percentile(0.95);

    private static double Rate(int n, int total) => total == 0 ? 0 : (double)n / total;

    private double Percentile(double p)
    {
        var sorted = Items.Select(i => i.Seconds).Order().ToList();
        if (sorted.Count == 0) return 0;
        var index = Math.Min(sorted.Count - 1, (int)Math.Ceiling(sorted.Count * p) - 1);
        return sorted[Math.Max(0, index)];
    }
}
