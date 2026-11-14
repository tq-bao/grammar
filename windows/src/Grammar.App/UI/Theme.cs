using System.Windows.Media;
using Microsoft.Win32;

namespace Grammar.App.UI;

/// <summary>Màu của panel theo chế độ sáng/tối của Windows (giống windowBackgroundColor trên macOS).</summary>
internal sealed record Theme(Color Background, Color Text, Color Secondary, Color Error, Color Fix, Color Accent)
{
    public static Theme Current => IsDarkMode() ? Dark : Light;

    public static readonly Theme Light = new(
        Background: Color.FromRgb(0xF3, 0xF3, 0xF3),
        Text: Color.FromRgb(0x1A, 0x1A, 0x1A),
        Secondary: Color.FromRgb(0x5F, 0x5F, 0x5F),
        Error: Color.FromRgb(0xD1, 0x34, 0x38),
        Fix: Color.FromRgb(0x10, 0x7C, 0x10),
        Accent: Color.FromRgb(0x00, 0x5F, 0xB8));

    public static readonly Theme Dark = new(
        Background: Color.FromRgb(0x20, 0x20, 0x20),
        Text: Color.FromRgb(0xF2, 0xF2, 0xF2),
        Secondary: Color.FromRgb(0xA8, 0xA8, 0xA8),
        Error: Color.FromRgb(0xFF, 0x63, 0x63),
        Fix: Color.FromRgb(0x6C, 0xCB, 0x5F),
        Accent: Color.FromRgb(0x60, 0xCD, 0xFF));

    private static bool IsDarkMode()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
        }
        catch (Exception)
        {
            return false;
        }
    }

    public static Color WithOpacity(Color c, double opacity) =>
        Color.FromArgb((byte)Math.Round(Math.Clamp(opacity, 0, 1) * 255), c.R, c.G, c.B);
}
