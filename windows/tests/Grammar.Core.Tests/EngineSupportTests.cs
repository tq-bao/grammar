using System.Text;
using System.Text.RegularExpressions;
using Grammar.Core.Engine;

namespace Grammar.Core.Tests;

// Port của OutputSanitizerTests và GrammarPromptTests trong GrammarAppTests/EngineTests.swift.
public class OutputSanitizerTests
{
    [Fact]
    public void StripsPrefixAndQuotes() =>
        Assert.Equal("They were happy.", OutputSanitizer.Clean("Corrected: \"They were happy.\"", "They was happy."));

    [Fact]
    public void TakesFirstNonEmptyLine() =>
        Assert.Equal("He has two cats.",
            OutputSanitizer.Clean("\n  He has two cats.\nExplanation: 'have' -> 'has'", "He have two cats."));

    [Fact]
    public void StripsSmartQuotesAndStackedPrefixes() =>
        Assert.Equal("I am here.", OutputSanitizer.Clean("Corrected text: Text: “I am here.”", "i am here."));

    [Fact]
    public void KeepsQuotesWhenOriginalHasThem() =>
        Assert.Equal("\"Stop,\" he said.\"", OutputSanitizer.Clean("\"Stop,\" he said.\"", "\"Stop,\" he say.\""));

    [Fact]
    public void EmptyOutputFallsBackToOriginal() =>
        Assert.Equal("I am fine.", OutputSanitizer.Clean("   \n ", "I am fine."));

    [Fact]
    public void WindowsLineEndings() =>
        Assert.Equal("He has two cats.", OutputSanitizer.Clean("He has two cats.\r\nNote: fixed", "He have two cats."));
}

public class GrammarPromptTests
{
    [Fact]
    public void MessagesEndWithUserSentence()
    {
        var messages = GrammarPrompt.Messages("They was happy.");
        Assert.Equal(GrammarPrompt.Role.System, messages[0].Role);
        Assert.Equal(new GrammarPrompt.Message(GrammarPrompt.Role.User, "Text: They was happy."), messages[^1]);
        Assert.Equal(2 + GrammarPrompt.Examples.Count * 2, messages.Count);
        Assert.Equal("user", messages[^1].RoleName);
    }
}

/// <summary>
/// Prompt của hai bản phải giống hệt nhau: đọc GrammarKit/Engine/GrammarPrompt.swift và so từng chuỗi.
/// Sửa prompt ở một bên mà quên bên kia thì test này fail.
/// </summary>
public class GrammarPromptParityTests
{
    private static readonly string Swift = File.ReadAllText(RepoPaths.SwiftPrompt);

    [Fact]
    public void SystemPromptMatchesSwift()
    {
        var match = Regex.Match(Swift, "public static let system = \"\"\"\\n(?<body>.*?)\\n(?<indent>[ ]*)\"\"\"", RegexOptions.Singleline);
        Assert.True(match.Success, "Không tìm thấy system prompt trong GrammarPrompt.swift");
        var indent = match.Groups["indent"].Value;
        // Chuỗi nhiều dòng của Swift bỏ đúng phần thụt đầu dòng bằng vị trí của """ đóng.
        var lines = match.Groups["body"].Value.Split('\n')
            .Select(l => l.StartsWith(indent, StringComparison.Ordinal) ? l[indent.Length..] : l.TrimStart());
        var swiftSystem = string.Join("\n", lines);
        Assert.Equal(swiftSystem, GrammarPrompt.System.ReplaceLineEndings("\n"));
    }

    [Fact]
    public void ExamplesMatchSwift()
    {
        var block = Regex.Match(Swift, @"public static let examples:.*?=\s*\[(?<body>.*?)\n\s*\]", RegexOptions.Singleline);
        Assert.True(block.Success, "Không tìm thấy examples trong GrammarPrompt.swift");
        var literals = Regex.Matches(block.Groups["body"].Value, "\"(?<s>(?:[^\"\\\\]|\\\\.)*)\"")
            .Select(m => Unescape(m.Groups["s"].Value))
            .ToList();
        var swiftExamples = literals.Chunk(2).Select(p => (p[0], p[1])).ToList();
        Assert.Equal(swiftExamples, GrammarPrompt.Examples);
    }

    [Fact]
    public void UserContentFormatMatchesSwift()
    {
        Assert.Contains("\"Text: \\(text)\"", Swift);
        Assert.Equal("Text: abc", GrammarPrompt.UserContent("abc"));
    }

    private static string Unescape(string s)
    {
        var sb = new StringBuilder();
        for (var i = 0; i < s.Length; i++)
        {
            if (s[i] == '\\' && i + 1 < s.Length)
            {
                i++;
                sb.Append(s[i] switch { 'n' => '\n', 't' => '\t', _ => s[i] });
            }
            else
            {
                sb.Append(s[i]);
            }
        }
        return sb.ToString();
    }
}
