using System.Drawing;
using System.Windows.Forms;

namespace Grammar.App.Tray;

/// <summary>
/// Icon ở khay hệ thống, thay cho menu bar của bản macOS (spec checker-window: "Điều khiển qua menu bar").
/// Menu: Ẩn/Hiện panel, Tạm dừng/Tiếp tục, Copy câu đã sửa, Cài đặt…, Thoát.
/// </summary>
internal sealed class TrayIcon : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly AppController _app;
    private readonly ToolStripMenuItem _togglePanel = new();
    private readonly ToolStripMenuItem _togglePause = new();
    private readonly ToolStripMenuItem _copy = new("Copy câu đã sửa");

    public TrayIcon(AppController app)
    {
        _app = app;
        var menu = new ContextMenuStrip();
        _togglePanel.Click += (_, _) => _app.TogglePanel();
        _togglePause.Click += (_, _) => _app.TogglePause();
        _copy.Click += (_, _) => _app.CopyCorrection();
        var settings = new ToolStripMenuItem("Cài đặt…");
        settings.Click += (_, _) => _app.OpenSettings();
        var quit = new ToolStripMenuItem("Thoát");
        quit.Click += (_, _) => _app.Quit();

        menu.Items.AddRange([_togglePanel, _togglePause, _copy, new ToolStripSeparator(), settings, new ToolStripSeparator(), quit]);
        // Cập nhật nhãn và trạng thái vô hiệu mỗi lần mở menu.
        menu.Opening += (_, _) => UpdateItems();

        _icon = new NotifyIcon
        {
            Icon = LoadIcon(),
            Text = "Grammar",
            ContextMenuStrip = menu,
            Visible = true,
        };
        _icon.DoubleClick += (_, _) => _app.TogglePanel();
        UpdateItems();
    }

    private void UpdateItems()
    {
        _togglePanel.Text = _app.IsPanelVisible ? "Ẩn panel" : "Hiện panel";
        _togglePause.Text = _app.IsPaused ? "Tiếp tục" : "Tạm dừng";
        // Spec: mục "Copy câu đã sửa" bị vô hiệu khi không có câu sửa.
        _copy.Enabled = _app.CanCopyCorrection;
    }

    private static Icon LoadIcon()
    {
        using var stream = typeof(TrayIcon).Assembly.GetManifestResourceStream("Grammar.App.Resources.Grammar.ico");
        return stream is null ? SystemIcons.Application : new Icon(stream, SystemInformation.SmallIconSize);
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
    }
}
