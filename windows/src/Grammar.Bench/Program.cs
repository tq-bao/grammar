// Grammar.Bench: chấm các model GGUF trên golden set (bản Windows của GrammarBench).
//
//   Grammar.Bench [--golden <golden.json>] --model <file.gguf> [--model ...] [--cpu] [--verbose]
//
// Không có --golden thì tìm GrammarAppTests/Fixtures/golden.json của repo, hoặc golden.json cạnh file chạy.
// --cpu: chạy hẳn bằng CPU (0 layer trên GPU), để đo máy không có GPU.

using System.Diagnostics;
using System.Globalization;
using Grammar.Core.Diff;
using Grammar.Core.Evaluation;
using Grammar.Engine;

CultureInfo.DefaultThreadCurrentCulture = CultureInfo.InvariantCulture;
CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
Console.OutputEncoding = System.Text.Encoding.UTF8;

string? goldenPath = null;
var models = new List<string>();
var verbose = false;
var cpuOnly = false;
for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--golden" when i + 1 < args.Length: goldenPath = args[++i]; break;
        case "--model" when i + 1 < args.Length: models.Add(args[++i]); break;
        case "--verbose": verbose = true; break;
        case "--cpu": cpuOnly = true; break;
        default:
            Console.Error.WriteLine($"Tham số không hợp lệ: {args[i]}");
            return 64;
    }
}

if (models.Count == 0)
{
    Console.WriteLine("Cần ít nhất một --model <file.gguf>");
    return 64;
}

goldenPath ??= GoldenSet.FindInRepo(Environment.CurrentDirectory)
               ?? GoldenSet.FindInRepo(AppContext.BaseDirectory)
               ?? Path.Combine(AppContext.BaseDirectory, "golden.json");
GoldenSet golden;
try
{
    golden = GoldenSet.Load(goldenPath);
}
catch (Exception e)
{
    Console.WriteLine($"Không đọc được golden set ({goldenPath}): {e.Message}");
    return 1;
}

static string Percent(double x) => $"{x * 100:0}%";
static string Ms(double s) => $"{s * 1000:0} ms";

var guardian = new EditGuard();
var summary = new List<(string Name, EvaluationReport Report, double Load, string Backend)>();

foreach (var modelPath in models)
{
    var name = Path.GetFileName(modelPath);
    Console.WriteLine($"\n=== {name} ===");

    var loadClock = Stopwatch.StartNew();
    LlamaGrammarEngine engine;
    string backend;
    try
    {
        if (cpuOnly)
        {
            engine = new LlamaGrammarEngine(modelPath, new LlamaGrammarEngine.Configuration { GpuLayers = 0 });
            await engine.WarmUpAsync();
            backend = "CPU";
        }
        else
        {
            var loaded = await BackendSelector.LoadAsync(modelPath);
            engine = loaded.Engine;
            backend = loaded.Backend == ComputeBackend.Gpu ? $"GPU ({engine.OffloadedLayers} layer)" : "CPU";
            if (loaded.GpuFallbackReason is { } reason) Console.WriteLine($"GPU lỗi, chuyển sang CPU: {reason}");
        }
    }
    catch (Exception e)
    {
        Console.WriteLine($"Lỗi nạp model: {e.Message}");
        continue;
    }
    var loadSeconds = loadClock.Elapsed.TotalSeconds;
    Console.WriteLine($"Đang chạy trên: {backend}");

    using (engine)
    {
        var report = new EvaluationReport();
        var cases = golden.Incorrect.Select(i => (i.Input, (IReadOnlyList<string>?)i.Expected))
            .Concat(golden.Correct.Select(c => (c, (IReadOnlyList<string>?)null)));

        foreach (var (input, expected) in cases)
        {
            var clock = Stopwatch.StartNew();
            string raw;
            try
            {
                raw = await engine.CorrectAsync(input);
            }
            catch (Exception)
            {
                raw = "<lỗi>";
            }
            // Giống app: bỏ qua khác biệt viết hoa/viết thường và dấu câu cuối câu.
            var output = CorrectionNormalizer.Reconcile(input, raw);
            var seconds = clock.Elapsed.TotalSeconds;
            var verdict = guardian.Evaluate(new WordDiff(input, output));
            var item = new EvaluationReport.Item(input, output, expected, verdict, seconds);
            report.Items.Add(item);

            if (verbose || !item.Passed)
            {
                var mark = item.Passed ? "✓" : "✗";
                var kind = expected is null ? "đúng" : "sai ";
                Console.WriteLine($"{mark} [{kind}] {input}\n      -> {output}{(verdict == EditVerdict.Rewritten ? "  (EditGuard: viết lại)" : "")}");
            }
        }

        Console.WriteLine($"Giữ nguyên câu đúng: {Percent(report.KeepRate)} | Khớp đáp án: {Percent(report.MatchRate)} | " +
                          $"Bị EditGuard loại: {Percent(report.RewriteRate)} | p50 {Ms(report.P50)} | p95 {Ms(report.P95)} | " +
                          $"nạp + warm-up {loadSeconds:0.0} s");
        summary.Add((name, report, loadSeconds, backend));
    }
}

Console.WriteLine("\n| Model | Phần cứng | Giữ nguyên câu đúng | Khớp đáp án | EditGuard loại | p50 | p95 | Nạp + warm-up |");
Console.WriteLine("|---|---|---|---|---|---|---|---|");
foreach (var row in summary)
{
    var r = row.Report;
    Console.WriteLine($"| {row.Name} | {row.Backend} | {Percent(r.KeepRate)} | {Percent(r.MatchRate)} | {Percent(r.RewriteRate)} | " +
                      $"{Ms(r.P50)} | {Ms(r.P95)} | {row.Load:0.0} s |");
}
return 0;
