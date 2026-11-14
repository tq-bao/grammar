namespace Grammar.Core.Tests;

/// <summary>Tìm các file dùng chung với bản macOS trong repo (golden set, prompt Swift).</summary>
internal static class RepoPaths
{
    /// <summary>Thư mục gốc repo: thư mục cha gần nhất có cả <c>GrammarKit</c> và <c>windows</c>.</summary>
    public static string Root
    {
        get
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir is not null)
            {
                if (Directory.Exists(Path.Combine(dir.FullName, "GrammarKit")) &&
                    Directory.Exists(Path.Combine(dir.FullName, "windows")))
                    return dir.FullName;
                dir = dir.Parent;
            }
            throw new DirectoryNotFoundException("Không tìm thấy thư mục gốc repo (cần GrammarKit/ và windows/).");
        }
    }

    public static string GoldenSet => Path.Combine(Root, "GrammarAppTests", "Fixtures", "golden.json");

    public static string SwiftPrompt => Path.Combine(Root, "GrammarKit", "Engine", "GrammarPrompt.swift");
}
