using System.Text.Json;
using Grammar.Core.Pipeline;
using Grammar.Core.Text;

namespace Grammar.Core.Tests;

// Port của LanguageGateTests trong GrammarAppTests/PipelineTests.swift, cộng các scenario trong spec grammar-correction.
public class LanguageGateTests
{
    private readonly LanguageGate _gate = new();

    [Theory]
    [InlineData("She go to school yesterday.")]
    [InlineData("He have two cats and they is cute.")]
    // Spec: "Câu tiếng Anh có tên riêng tiếng Việt".
    [InlineData("Hi, my name is Bao")]
    [InlineData("ok I will ping Tuan")]
    [InlineData("my name is Bao")]
    [InlineData("Hi Minh, can you check the PR?")]
    [InlineData("Hi, my name is Bảo")]
    [InlineData("gonna send u the file tmr, it have the numbers")]
    public void English(string sentence) => Assert.Equal(LanguageVerdict.English, _gate.Evaluate(sentence));

    [Theory]
    // Spec: "Câu tiếng Việt" và "Tiếng Việt không dấu".
    [InlineData("Hôm nay tôi đi học muộn.")]
    [InlineData("hom nay toi di hoc muon")]
    [InlineData("anh check giup em cai PR nay nhe")]
    [InlineData("Bao oi, an com chua")]
    [InlineData("Anh gửi em cái file report nhé, cảm ơn anh nhiều.")]
    // Ngôn ngữ khác.
    [InlineData("Danke schön, wir sehen uns morgen")]
    [InlineData("Je suis très fatigué aujourd'hui")]
    public void NotEnglish(string sentence) => Assert.Equal(LanguageVerdict.NotEnglish, _gate.Evaluate(sentence));

    [Theory]
    // Spec: "Câu quá ngắn".
    [InlineData("ok thanks")]
    [InlineData("👍 !!")]
    public void TooShort(string sentence) => Assert.Equal(LanguageVerdict.TooShort, _gate.Evaluate(sentence));

    [Theory]
    [InlineData("hom", true)]
    [InlineData("nghieng", true)]   // nghiêng: vần "iêng"
    [InlineData("tieng", true)]
    [InlineData("nghiep", true)]
    [InlineData("giup", true)]
    [InlineData("gi", true)]
    [InlineData("quyen", true)]
    [InlineData("khong", true)]
    [InlineData("check", false)]
    [InlineData("report", false)]
    [InlineData("school", false)]
    public void VietnameseSyllables(string syllable, bool valid) =>
        Assert.Equal(valid, VietnameseSyllable.IsValid(syllable));

    [Fact]
    public void RemovesVietnameseDiacritics()
    {
        Assert.Equal("tuan", LanguageDetector.RemoveDiacritics("tuấn"));
        Assert.Equal("di", LanguageDetector.RemoveDiacritics("đi"));
        Assert.Equal("nguoi", LanguageDetector.RemoveDiacritics("người"));
    }

    [Theory]
    [InlineData("restarting")]
    [InlineData("passing")]
    [InlineData("pushed")]
    [InlineData("stopped")]
    [InlineData("cats")]
    [InlineData("doesn't")]
    [InlineData("it's")]
    [InlineData("studies")]
    public void EnglishMorphology(string word) => Assert.True(LanguageDetector.IsEnglish(word));
}

/// <summary>
/// Đối chiếu với LanguageGate.swift thật (NLLanguageRecognizer của macOS) trên bộ câu
/// Fixtures/language-corpus.json cộng toàn bộ golden set (đáp án ở Fixtures/language-oracle.json,
/// sinh bằng windows/scripts/gen-language-oracle.swift).
/// </summary>
public class LanguageGateParityTests
{
    private sealed record OracleItem(string Sentence, string Verdict, double EnglishProbability);

    /// <summary>
    /// Khác biệt đã biết và chấp nhận, đều là chỗ NLLanguageRecognizer (được báo trước người dùng gõ tiếng Anh/Việt)
    /// nhận nhầm là tiếng Anh: hai câu tiếng Đức/Pháp, và một câu tiếng Việt không dấu chen từ tiếng Anh.
    /// Bản Windows coi các câu này là không phải tiếng Anh.
    /// </summary>
    private static readonly Dictionary<string, LanguageVerdict> KnownDifferences = new()
    {
        ["Ich habe keine Zeit heute"] = LanguageVerdict.NotEnglish,
        ["Où est la gare s'il vous plaît"] = LanguageVerdict.NotEnglish,
        ["ok de em update ticket"] = LanguageVerdict.NotEnglish,
    };

    [Fact]
    public void MatchesMacOSLanguageGate()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "language-oracle.json"));
        var items = JsonSerializer.Deserialize<OracleItem[]>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
        Assert.True(items.Length > 100);

        var gate = new LanguageGate();
        var failures = new List<string>();
        foreach (var item in items)
        {
            var expected = KnownDifferences.TryGetValue(item.Sentence, out var known)
                ? known
                : Enum.Parse<LanguageVerdict>(item.Verdict, ignoreCase: true);
            var actual = gate.Evaluate(item.Sentence);
            if (actual != expected)
            {
                var s = LanguageDetector.Score(item.Sentence);
                failures.Add($"{item.Sentence} | macOS: {item.Verdict} ({item.EnglishProbability}) | C#: {actual} " +
                             $"(en={s.English} vi={s.Vietnamese:0.#} other={s.Other} p={s.EnglishProbability:0.00})");
            }
        }
        Assert.True(failures.Count == 0, $"{failures.Count} câu khác macOS:\n" + string.Join("\n", failures));
    }
}

/// <summary>
/// Ghi điểm của mọi câu trong oracle ra file, dùng khi chỉnh danh sách từ:
/// GRAMMAR_LANG_DUMP=/tmp/scores.txt dotnet test --filter LanguageScoreDump
/// </summary>
public class LanguageScoreDump
{
    private sealed record OracleItem(string Sentence, string Verdict, double EnglishProbability);

    [Fact]
    public void Dump()
    {
        var path = Environment.GetEnvironmentVariable("GRAMMAR_LANG_DUMP");
        if (string.IsNullOrEmpty(path)) return;
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "language-oracle.json"));
        var lines = JsonSerializer.Deserialize<OracleItem[]>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!
            .Select(item =>
            {
                var s = LanguageDetector.Score(item.Sentence);
                return $"{s.EnglishProbability:0.00} en={s.English} vi={s.Vietnamese:0.#} other={s.Other} | mac={item.Verdict} {item.EnglishProbability:0.00} | {item.Sentence}";
            });
        File.WriteAllLines(path, lines);
    }
}
