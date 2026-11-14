namespace Grammar.Core.Panel;

/// <summary>Góc màn hình đặt panel.</summary>
public enum PanelCorner
{
    TopRight,
    TopLeft,
    BottomRight,
    BottomLeft,
}

/// <summary>Một điểm trong hệ toạ độ màn hình của Windows (gốc ở góc trên trái, trục y hướng xuống), đơn vị DIP.</summary>
public readonly record struct Point(double X, double Y);

/// <summary>Kích thước, đơn vị DIP.</summary>
public readonly record struct Size(double Width, double Height);

/// <summary>Hình chữ nhật trong hệ toạ độ gốc trên trái, đơn vị DIP.</summary>
public readonly record struct Rect(double X, double Y, double Width, double Height)
{
    public double Left => X;
    public double Top => Y;
    public double Right => X + Width;
    public double Bottom => Y + Height;

    /// <summary>Nửa mở như <c>CGRect.contains</c>: cạnh trái/trên thuộc vùng, cạnh phải/dưới thì không.</summary>
    public bool Contains(Point p) => p.X >= Left && p.X < Right && p.Y >= Top && p.Y < Bottom;

    public bool Contains(Rect r) => r.Left >= Left && r.Right <= Right && r.Top >= Top && r.Bottom <= Bottom;
}

/// <summary>
/// Tính khung panel theo góc đã chọn. Port của GrammarKit/Panel/PanelLayout.swift, đổi sang hệ toạ độ
/// của Windows (gốc trên trái) thay cho hệ của AppKit (gốc dưới trái). Quy tắc giữ nguyên.
/// </summary>
public static class PanelLayout
{
    public const double DefaultMargin = 20;
    /// <summary>Chiều cao dải header luôn nhận chuột (để kéo panel).</summary>
    public const double HeaderHeight = 24;

    /// <summary>Dải header ở cạnh trên của khung panel.</summary>
    public static Rect HeaderRect(Rect panel) => panel with { Height = Math.Min(HeaderHeight, panel.Height) };

    /// <param name="corner">Góc đã chọn.</param>
    /// <param name="size">Kích thước mong muốn (độ rộng theo cài đặt, chiều cao theo nội dung).</param>
    /// <param name="workArea">Vùng làm việc của màn hình (đã trừ taskbar).</param>
    /// <param name="margin">Khoảng cách tới mép.</param>
    /// <returns>Khung cách mép <paramref name="margin"/>. Panel lớn hơn màn hình thì bị kẹp vào trong.</returns>
    public static Rect Frame(PanelCorner corner, Size size, Rect workArea, double margin = DefaultMargin)
    {
        var width = Math.Min(size.Width, Math.Max(0, workArea.Width - 2 * margin));
        var height = Math.Min(size.Height, Math.Max(0, workArea.Height - 2 * margin));
        var isLeft = corner is PanelCorner.TopLeft or PanelCorner.BottomLeft;
        var isTop = corner is PanelCorner.TopLeft or PanelCorner.TopRight;
        var x = isLeft ? workArea.Left + margin : workArea.Right - margin - width;
        var y = isTop ? workArea.Top + margin : workArea.Bottom - margin - height;
        return new Rect(x, y, width, height);
    }

    /// <summary>
    /// Khung panel giữ góc trên trái tại <paramref name="topLeft"/> (vị trí người dùng đã kéo),
    /// được dời vào trong để nằm trọn <paramref name="workArea"/>.
    /// </summary>
    public static Rect Frame(Point topLeft, Size size, Rect workArea)
    {
        var width = Math.Min(size.Width, workArea.Width);
        var height = Math.Min(size.Height, workArea.Height);
        var x = Math.Min(Math.Max(topLeft.X, workArea.Left), workArea.Right - width);
        var y = Math.Min(Math.Max(topLeft.Y, workArea.Top), workArea.Bottom - height);
        return new Rect(x, y, width, height);
    }
}
