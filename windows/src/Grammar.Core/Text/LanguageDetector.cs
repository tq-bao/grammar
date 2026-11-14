using System.Globalization;
using System.Reflection;
using System.Text;

namespace Grammar.Core.Text;

/// <summary>
/// Ước lượng khả năng một câu là tiếng Anh, chạy hoàn toàn trên máy, thay cho <c>NLLanguageRecognizer</c>
/// của macOS (không có trên Windows). Người dùng chủ yếu gõ tiếng Anh và tiếng Việt, nên bộ nhận diện
/// phân biệt rõ hai thứ tiếng này; ngôn ngữ khác bị tính là không phải tiếng Anh.
/// </summary>
/// <remarks>
/// Mỗi từ được xếp vào một nhóm:
/// <list type="bullet">
/// <item><b>Anh</b>: có trong danh sách từ tiếng Anh thông dụng (Resources/english-words.txt), sau khi bỏ hậu tố.</item>
/// <item><b>Việt</b>: âm tiết tiếng Việt hợp lệ (có dấu tiếng Việt, hoặc không dấu nhưng đúng cấu trúc âm đầu + vần)
/// và không phải từ tiếng Anh.</item>
/// <item><b>Khác</b>: từ viết thường không thuộc hai nhóm trên, hoặc có dấu không thuộc tiếng Việt (ö, ß, ç...).</item>
/// <item><b>Bỏ qua</b>: từ thuộc cả hai thứ tiếng (the, an, to...), tên riêng viết hoa (Bao, Tuan), từ viết tắt
/// viết hoa (PR, API), token có chữ số.</item>
/// </list>
/// Khả năng tiếng Anh = Anh / (Anh + Việt + 0.5 × Khác). Không có từ nào được tính thì coi là tiếng Anh.
/// Hư từ và đại từ tiếng Việt (anh, em, ơi, rồi, nhé, chưa...) tính gấp đôi: chúng gần như chỉ xuất hiện trong câu
/// tiếng Việt, kể cả câu chen nhiều từ kỹ thuật tiếng Anh ("anh oi deploy staging fail roi"). Còn danh từ tiếng Việt
/// trong câu tiếng Anh (pho, banh mi, Da Nang) chỉ tính một lần.
/// </remarks>
public static class LanguageDetector
{
    /// <summary>Trọng số của từ không rõ ngôn ngữ: từ hiếm, lỗi chính tả trong câu tiếng Anh vẫn có.</summary>
    internal const double OtherWeight = 0.5;

    private static readonly Lazy<HashSet<string>> EnglishWords = new(LoadEnglishWords);

    /// <summary>Trọng số của hư từ/đại từ tiếng Việt.</summary>
    internal const double FunctionWordWeight = 2;

    /// <summary>
    /// Hư từ, đại từ, trợ từ tiếng Việt thông dụng (đã bỏ dấu). Chỉ những âm tiết không phải từ tiếng Anh;
    /// âm tiết trùng tiếng Anh (the, an, to...) đã bị bỏ qua trước khi xét danh sách này.
    /// </summary>
    private static readonly HashSet<string> VietnameseFunctionWords =
    [
        "anh", "em", "chi", "ban", "minh", "toi", "tao", "may", "no", "ho", "bon", "chung",
        "oi", "a", "nhe", "nha", "nhi", "ha", "ne", "nhen", "roi", "chua", "khong", "ko", "da", "dang", "se",
        "cua", "cho", "la", "va", "thi", "ma", "nay", "kia", "do", "vay", "sao", "gi", "duoc", "bi", "cung",
        "voi", "den", "tu", "trong", "len", "xuong", "lai", "nua", "het", "ve", "o", "voi", "nao", "nhung",
        "cac", "moi", "nhieu", "it", "rat", "qua", "lam", "de", "neu", "vi", "nen", "con", "hay", "hoac",
    ];

    /// <summary>Kết quả đếm theo nhóm, để test và chẩn đoán.</summary>
    /// <param name="Vietnamese">Điểm tiếng Việt (hư từ tính gấp đôi).</param>
    public readonly record struct Scores(int English, double Vietnamese, int Other)
    {
        public double EnglishProbability
        {
            get
            {
                var total = English + Vietnamese + OtherWeight * Other;
                return total <= 0 ? 1 : English / total;
            }
        }
    }

    internal enum WordClass
    {
        Skip,
        English,
        Vietnamese,
        Other,
    }

    public static double EnglishProbability(string sentence) => Score(sentence).EnglishProbability;

    public static Scores Score(string sentence)
    {
        int en = 0, other = 0;
        double vi = 0;
        foreach (var token in Diff.WordTokenizer.Tokenize(sentence))
        {
            switch (Classify(token.Text))
            {
                case WordClass.English: en++; break;
                case WordClass.Vietnamese:
                    vi += VietnameseFunctionWords.Contains(RemoveDiacritics(token.Text.ToLowerInvariant()))
                        ? FunctionWordWeight
                        : 1;
                    break;
                case WordClass.Other: other++; break;
            }
        }
        return new Scores(en, vi, other);
    }

    internal static WordClass Classify(string word)
    {
        if (!Graphemes.ContainsLetter(word)) return WordClass.Skip;   // dấu câu, emoji
        if (word.Any(char.IsDigit)) return WordClass.Skip;            // 5h, v2, 10am

        var letters = word.Where(char.IsLetter).ToArray();
        var isAllCaps = letters.Length >= 2 && letters.All(char.IsUpper);
        if (isAllCaps) return WordClass.Skip;                         // PR, API, OK
        var isCapitalized = char.IsUpper(word[0]);

        var lower = word.ToLowerInvariant().Replace('’', '\'');
        var isAscii = lower.All(c => c < 128);

        if (!isAscii)
        {
            // Có dấu: tiếng Việt nếu mọi chữ có dấu đều là chữ tiếng Việt và bỏ dấu ra là âm tiết hợp lệ.
            if (lower.All(c => c < 128 || VietnameseLetters.Contains(c)) &&
                VietnameseSyllable.IsValid(RemoveDiacritics(lower)))
                return isCapitalized ? WordClass.Skip : WordClass.Vietnamese;  // viết hoa: tên riêng (Bảo) hoặc đầu câu
            return WordClass.Other;
        }

        var english = IsEnglish(lower);
        var vietnamese = VietnameseSyllable.IsValid(lower);
        if (english && vietnamese) return WordClass.Skip;
        if (english) return WordClass.English;
        // Từ viết hoa không phải tiếng Anh: thường là tên riêng (Bao, Tuan, Ha Noi).
        if (isCapitalized) return WordClass.Skip;
        return vietnamese ? WordClass.Vietnamese : WordClass.Other;
    }

    /// <summary>Từ (viết thường, không dấu) có trong danh sách tiếng Anh, thử cả khi bỏ hậu tố.</summary>
    internal static bool IsEnglish(string word)
    {
        var words = EnglishWords.Value;
        if (words.Contains(word)) return true;

        // Rút gọn: it's -> it, john's -> john.
        var apostrophe = word.IndexOf('\'');
        if (apostrophe > 0)
        {
            var head = word[..apostrophe];
            return head.Length >= 2 && IsEnglish(head);
        }

        foreach (var stem in Stems(word))
            if (stem.Length >= 2 && words.Contains(stem)) return true;
        return false;
    }

    /// <summary>Các dạng gốc có thể có của một từ đã bỏ hậu tố.</summary>
    private static IEnumerable<string> Stems(string w)
    {
        if (w.EndsWith("ies")) yield return w[..^3] + "y";
        if (w.EndsWith("es")) yield return w[..^2];
        if (w.EndsWith('s')) yield return w[..^1];
        if (w.EndsWith("ied")) yield return w[..^3] + "y";
        if (w.EndsWith("ed"))
        {
            yield return w[..^2];
            yield return w[..^1];                                 // used -> use
            if (w.Length > 4 && w[^3] == w[^4]) yield return w[..^3];  // stopped -> stop
        }
        if (w.EndsWith("ing"))
        {
            yield return w[..^3];
            yield return w[..^3] + "e";                           // making -> make
            if (w.Length > 5 && w[^4] == w[^5]) yield return w[..^4];  // running -> run
        }
        if (w.EndsWith("ly")) yield return w[..^2];
        if (w.EndsWith("ily")) yield return w[..^3] + "y";
        if (w.EndsWith("er")) { yield return w[..^2]; yield return w[..^1]; }
        if (w.EndsWith("est")) { yield return w[..^3]; yield return w[..^2]; }
        if (w.EndsWith("ness")) yield return w[..^4];
        if (w.EndsWith("ment")) yield return w[..^4];
        if (w.EndsWith("able")) yield return w[..^4];
    }

    /// <summary>Chữ cái có dấu dùng trong tiếng Việt (viết thường).</summary>
    private static readonly HashSet<char> VietnameseLetters =
    [
        .. "àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ",
    ];

    /// <summary>Bỏ dấu tiếng Việt: "Tuấn" -> "tuan", "đi" -> "di".</summary>
    internal static string RemoveDiacritics(string text)
    {
        var sb = new StringBuilder(text.Length);
        foreach (var c in text.Replace('đ', 'd').Replace('Đ', 'D').Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark) sb.Append(c);
        return sb.ToString().Normalize(NormalizationForm.FormC);
    }

    private static HashSet<string> LoadEnglishWords()
    {
        var assembly = typeof(LanguageDetector).Assembly;
        var name = assembly.GetManifestResourceNames().Single(n => n.EndsWith("english-words.txt", StringComparison.Ordinal));
        using var stream = assembly.GetManifestResourceStream(name)!;
        using var reader = new StreamReader(stream, Encoding.UTF8);
        var words = new HashSet<string>(StringComparer.Ordinal);
        while (reader.ReadLine() is { } line)
        {
            if (line.StartsWith('#')) continue;
            foreach (var w in line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries))
                words.Add(w.ToLowerInvariant());
        }
        return words;
    }
}

/// <summary>Kiểm tra một chuỗi (viết thường, đã bỏ dấu) có đúng cấu trúc âm tiết tiếng Việt: âm đầu + vần.</summary>
internal static class VietnameseSyllable
{
    /// <summary>Âm đầu, xếp dài trước ngắn để khớp tham lam ("ngh" trước "ng" trước "n").</summary>
    private static readonly string[] Onsets =
    [
        "ngh", "ng", "nh", "ch", "gh", "gi", "kh", "ph", "qu", "th", "tr",
        "b", "c", "d", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "x",
    ];

    /// <summary>Vần (đã bỏ dấu: ă/â -> a, ê -> e, ô/ơ -> o, ư -> u).</summary>
    private static readonly HashSet<string> Rhymes =
    [
        "a", "ac", "ach", "ai", "am", "an", "ang", "anh", "ao", "ap", "at", "au", "ay",
        "e", "ec", "ech", "em", "en", "eng", "enh", "eo", "ep", "et", "eu",
        "i", "ia", "ich", "iec", "iem", "ien", "ieng", "iep", "iet", "ieu", "im", "in", "inh", "ip", "it", "iu",
        "o", "oa", "oac", "oach", "oai", "oam", "oan", "oang", "oanh", "oao", "oap", "oat", "oay",
        "oc", "oe", "oen", "oeo", "oet", "oi", "om", "on", "ong", "ooc", "oong", "op", "ot",
        "u", "ua", "uan", "uang", "uanh", "uat", "uay", "uc", "ue", "uech", "uen", "uenh", "uet", "ui",
        "um", "un", "ung", "uo", "uoc", "uoi", "uom", "uon", "uong", "uop", "uot", "uou", "up", "ut", "uu",
        "uy", "uya", "uych", "uyen", "uyet", "uynh", "uyt", "uyu",
        "y", "yem", "yen", "yet", "yeu",
    ];

    public static bool IsValid(string syllable)
    {
        if (syllable.Length == 0 || syllable.Length > 7) return false;
        if (Rhymes.Contains(syllable)) return true;            // không có âm đầu: an, em, oi
        foreach (var onset in Onsets)
        {
            if (!syllable.StartsWith(onset, StringComparison.Ordinal)) continue;
            var rhyme = syllable[onset.Length..];
            if (Rhymes.Contains(rhyme)) return true;
            // "gi" và "qu" đứng một mình hoặc dính nguyên âm: gì, gia (gi + a), qua (qu + a).
            if (onset is "gi" && (rhyme.Length == 0 || Rhymes.Contains("i" + rhyme))) return true;
        }
        return false;
    }
}
