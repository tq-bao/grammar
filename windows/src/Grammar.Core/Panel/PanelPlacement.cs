namespace Grammar.Core.Panel;

/// <summary>
/// Đặt panel lên một màn hình cụ thể, tính bằng pixel vật lý của màn hình ảo Windows.
/// </summary>
/// <remarks>
/// Các kích thước trong spec (độ rộng 460, header 24, cách mép 20) là đơn vị độc lập thiết bị (DIP, 1/96 inch).
/// Mỗi màn hình có thể có scale khác nhau (100%, 150%...), nên toạ độ DIP không liên tục giữa các màn hình.
/// Vì vậy vị trí được tính và lưu bằng pixel vật lý, còn kích thước được nhân với scale của màn hình chứa panel.
/// </remarks>
public static class PanelPlacement
{
    /// <param name="settings">Cài đặt: góc, vị trí đã kéo (pixel vật lý).</param>
    /// <param name="contentSizeDip">Kích thước panel theo nội dung (DIP).</param>
    /// <param name="workAreaPx">Vùng làm việc của màn hình chứa panel (pixel vật lý, đã trừ taskbar).</param>
    /// <param name="scale">Scale của màn hình đó (1.0 = 100%, 1.5 = 150%).</param>
    /// <returns>Khung panel bằng pixel vật lý.</returns>
    public static Rect Compute(PanelCorner corner, Point? customTopLeftPx, Size contentSizeDip, Rect workAreaPx, double scale)
    {
        var sizePx = new Size(contentSizeDip.Width * scale, contentSizeDip.Height * scale);
        return customTopLeftPx is { } topLeft
            ? PanelLayout.Frame(topLeft, sizePx, workAreaPx)
            : PanelLayout.Frame(corner, sizePx, workAreaPx, PanelLayout.DefaultMargin * scale);
    }

    /// <summary>Dải header bằng pixel vật lý, để biết chuột có đang ở trên header không.</summary>
    public static Rect HeaderRect(Rect panelPx, double scale) =>
        panelPx with { Height = Math.Min(PanelLayout.HeaderHeight * scale, panelPx.Height) };
}
