using Grammar.Core.Diff;
using Grammar.Core.Text;

namespace Grammar.Core.Pipeline;

/// <summary>Kết luận của <see cref="LanguageGate"/>.</summary>
public enum LanguageVerdict
{
    English,
    NotEnglish,
    TooShort,
}

/// <summary>
/// Quyết định một câu có được đưa đi kiểm tra ngữ pháp hay không.
/// Port của GrammarKit/Pipeline/LanguageGate.swift, dùng <see cref="LanguageDetector"/> thay cho NLLanguageRecognizer.
/// </summary>
/// <param name="MinimumWords">Số từ tối thiểu (từ có chữ cái).</param>
/// <param name="MinimumConfidence">Khả năng là tiếng Anh tối thiểu. 0.5 nghĩa là tiếng Anh phải là khả năng cao nhất.</param>
public sealed record LanguageGate(int MinimumWords = 3, double MinimumConfidence = 0.5)
{
    public LanguageVerdict Evaluate(string sentence)
    {
        var words = WordTokenizer.Tokenize(sentence).Count(t => Graphemes.ContainsLetter(t.Text));
        if (words < MinimumWords) return LanguageVerdict.TooShort;
        return LanguageDetector.EnglishProbability(sentence) >= MinimumConfidence
            ? LanguageVerdict.English
            : LanguageVerdict.NotEnglish;
    }
}
