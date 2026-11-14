using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;
using System.Windows.Threading;
using Grammar.Core.Diff;
using Grammar.Core.Panel;
using Grammar.Core.Pipeline;
using Microsoft.Win32;
using CorePoint = Grammar.Core.Panel.Point;
using CoreSize = Grammar.Core.Panel.Size;

namespace Grammar.App.UI;

/// <summary>
/// Panel chỉ để xem: nền trong suốt theo cài đặt, luôn nổi trên cùng, không bao giờ lấy focus.
/// Bản Windows của CheckerPanel.swift + TwoPaneView.swift.
/// </summary>
/// <remarks>
/// <list type="bullet">
/// <item>Không lấy focus: <c>WS_EX_NOACTIVATE</c> và trả <c>MA_NOACTIVATE</c> cho <c>WM_MOUSEACTIVATE</c>.</item>
/// <item>Click xuyên qua: bật <c>WS_EX_TRANSPARENT</c> cho cả cửa sổ. Một timer đọc vị trí chuột; khi chuột nằm trên
/// header thì tạm bỏ <c>WS_EX_TRANSPARENT</c> để header nhận chuột (giống <c>ignoresMouseEvents</c> của bản macOS).</item>
/// <item>Vị trí tính bằng pixel vật lý theo màn hình chứa panel (<see cref="PanelPlacement"/>).</item>
/// </list>
/// </remarks>
internal sealed class PanelWindow : Window
{
    private const double CornerRadius = 12;

    private readonly PanelSettings _settings;
    private readonly CheckCoordinator _coordinator;
    private readonly Func<bool> _isPaused;
    private readonly Theme _theme = Theme.Current;

    private readonly Border _background = new() { CornerRadius = new CornerRadius(CornerRadius) };
    private readonly Border _header = new() { Height = PanelLayout.HeaderHeight, CornerRadius = new CornerRadius(CornerRadius, CornerRadius, 0, 0) };
    private readonly Rectangle _dragBorder = new()
    {
        RadiusX = CornerRadius,
        RadiusY = CornerRadius,
        StrokeThickness = 2,
        StrokeDashArray = [3, 2],
        IsHitTestVisible = false,
    };
    private readonly TextBlock _original = NewSentenceBlock();
    private readonly TextBlock _corrected = NewSentenceBlock();
    private readonly TextBlock _status = new() { FontSize = 11, VerticalAlignment = VerticalAlignment.Center };
    private readonly Border _statusBadge = new() { CornerRadius = new CornerRadius(9), Padding = new Thickness(8, 2, 8, 2) };
    private readonly DispatcherTimer _mouseTimer = new(DispatcherPriority.Input) { Interval = TimeSpan.FromMilliseconds(30) };

    private IntPtr _hwnd;
    private bool _isTransparent;
    private bool _applyingLayout;
    private bool _relayoutScheduled;

    public PanelWindow(PanelSettings settings, CheckCoordinator coordinator, Func<bool> isPaused)
    {
        _settings = settings;
        _coordinator = coordinator;
        _isPaused = isPaused;

        Title = "Grammar";
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        Topmost = true;
        ShowInTaskbar = false;
        ShowActivated = false;
        Focusable = false;
        SizeToContent = SizeToContent.Height;
        Width = settings.Width;
        UseLayoutRounding = true;

        Content = BuildContent();
        ApplyColors();
        Render();

        _mouseTimer.Tick += (_, _) => UpdateMouseInteraction();
        _settings.PropertyChanged += OnSettingsChanged;
        _coordinator.PropertyChanged += (_, _) => Render();
        SizeChanged += (_, _) => ScheduleRelayout();
        DpiChanged += (_, _) => ScheduleRelayout();
        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
        IsVisibleChanged += (_, _) => UpdateMouseTimer();
    }

    /// <summary>Hiện panel mà không lấy focus.</summary>
    public void ShowPanel()
    {
        Show();
        Relayout();
        UpdateMouseInteraction();
    }

    /// <summary>Gọi khi trạng thái tạm dừng đổi (nhãn trạng thái).</summary>
    public void Refresh() => Render();

    // ---- Dựng giao diện ----

    private static TextBlock NewSentenceBlock() => new()
    {
        FontSize = 14,
        TextWrapping = TextWrapping.Wrap,
        Margin = new Thickness(0, 2, 0, 0),
    };

    private UIElement BuildContent()
    {
        var grip = new TextBlock { Text = "≡", FontSize = 13, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 6, 0), VerticalAlignment = VerticalAlignment.Center };
        var name = new TextBlock { Text = "Grammar", FontSize = 11, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center };
        _header.Child = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(12, 0, 12, 0), Children = { grip, name } };
        _header.ToolTip = "Kéo để di chuyển panel";
        _header.Cursor = Cursors.SizeAll;
        _header.MouseLeftButtonDown += (_, e) =>
        {
            e.Handled = true;
            BeginDrag(e);
        };

        _statusBadge.Child = _status;
        var originalTitle = new TextBlock { Text = "Câu đang gõ", FontSize = 13, FontWeight = FontWeights.SemiBold };
        var titleRow = new DockPanel { LastChildFill = false };
        DockPanel.SetDock(_statusBadge, Dock.Right);
        titleRow.Children.Add(_statusBadge);
        titleRow.Children.Add(originalTitle);

        var correctedTitle = new TextBlock { Text = "Câu đã sửa", FontSize = 13, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 8, 0, 0) };
        var divider = new Border { Height = 1, Margin = new Thickness(0, 8, 0, 0), Opacity = 0.3 };
        divider.SetResourceReference(Border.BackgroundProperty, SystemColors.GrayTextBrushKey);

        var body = new StackPanel
        {
            Margin = new Thickness(14, 8, 14, 14),
            Children = { titleRow, _original, divider, correctedTitle, _corrected },
            // Viền mờ màu nền giúp chữ vẫn đọc được khi nền gần như trong suốt (giống shadow của bản macOS).
            Effect = new DropShadowEffect { Color = _theme.Background, BlurRadius = 3, ShadowDepth = 0, Opacity = 0.9 },
        };

        var stack = new DockPanel();
        DockPanel.SetDock(_header, Dock.Top);
        stack.Children.Add(_header);
        stack.Children.Add(body);
        _background.Child = stack;
        _background.MouseLeftButtonDown += (_, e) =>
        {
            if (!_settings.ClickThrough) BeginDrag(e);
        };

        var root = new Grid();
        root.Children.Add(_background);
        root.Children.Add(_dragBorder);
        TextElement.SetForeground(root, new SolidColorBrush(_theme.Text));
        return root;
    }

    private void ApplyColors()
    {
        _background.Background = new SolidColorBrush(Theme.WithOpacity(_theme.Background, _settings.BackgroundOpacity));
        // Header luôn có nền mờ tối thiểu 60% để vẫn thấy và kéo được khi nền trong suốt.
        _header.Background = new SolidColorBrush(Theme.WithOpacity(_theme.Background, Math.Max(_settings.BackgroundOpacity, 0.6)));
        _header.Child.SetValue(TextElement.ForegroundProperty, new SolidColorBrush(_theme.Secondary));
        // Đang tắt click xuyên qua: viền nét đứt báo panel đang kéo được.
        _dragBorder.Stroke = new SolidColorBrush(_theme.Accent);
        _dragBorder.Visibility = _settings.ClickThrough ? Visibility.Collapsed : Visibility.Visible;
        _background.Cursor = _settings.ClickThrough ? null : Cursors.SizeAll;
    }

    private void Render()
    {
        var content = PanelPresenter.Present(_coordinator.State, _coordinator.Sentence, _isPaused());
        Fill(_original, content.Original, content.OriginalIsPlaceholder ? _theme.Secondary : _theme.Text);
        Fill(_corrected, content.Corrected,
            content.CorrectedIsError ? _theme.Error : content.CorrectedIsPlaceholder ? _theme.Secondary : _theme.Text);

        var tone = content.Tone switch
        {
            StatusTone.Good => _theme.Fix,
            StatusTone.Bad => _theme.Error,
            StatusTone.Warning => Color.FromRgb(0xE8, 0x8A, 0x00),
            _ => _theme.Secondary,
        };
        _status.Text = $"{Symbol(content.Icon)} {content.Status}";
        _status.Foreground = new SolidColorBrush(tone);
        _statusBadge.Background = new SolidColorBrush(Theme.WithOpacity(tone, 0.15));
    }

    private static string Symbol(StatusIcon icon) => icon switch
    {
        StatusIcon.Paused => "⏸",
        StatusIcon.Waiting => "⌨",
        StatusIcon.Busy => "⌛",
        StatusIcon.Ok => "✔",
        StatusIcon.Error => "❗",
        StatusIcon.Language => "\U0001F310",
        StatusIcon.Question => "?",
        StatusIcon.Failure => "✖",
        _ => "",
    };

    /// <summary>Dựng các Run có gạch chân đỏ, ô đỏ ở chỗ thiếu từ, chữ xanh đậm ở phần sửa.</summary>
    private void Fill(TextBlock block, IReadOnlyList<StyledSegment> segments, Color baseColor)
    {
        block.Inlines.Clear();
        block.Foreground = new SolidColorBrush(baseColor);
        var errorPen = new Pen(new SolidColorBrush(_theme.Error), 1.5);
        foreach (var segment in segments)
        {
            var run = new Run(segment.Text);
            switch (segment.Style)
            {
                case SegmentStyle.Error:
                    run.TextDecorations = [new TextDecoration(TextDecorationLocation.Underline, errorPen, 1, TextDecorationUnit.FontRecommended, TextDecorationUnit.FontRecommended)];
                    break;
                case SegmentStyle.Gap:
                    run.TextDecorations = [new TextDecoration(TextDecorationLocation.Underline, new Pen(new SolidColorBrush(_theme.Error), 2.5), 1, TextDecorationUnit.FontRecommended, TextDecorationUnit.FontRecommended)];
                    run.Background = new SolidColorBrush(Theme.WithOpacity(_theme.Error, 0.3));
                    break;
                case SegmentStyle.Fix:
                    run.Foreground = new SolidColorBrush(_theme.Fix);
                    run.FontWeight = FontWeights.Bold;
                    break;
            }
            block.Inlines.Add(run);
        }
    }

    // ---- Không lấy focus, click xuyên qua ----

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        _hwnd = new WindowInteropHelper(this).Handle;
        NativeMethods.SetExtendedStyle(_hwnd, NativeMethods.WS_EX_NOACTIVATE | NativeMethods.WS_EX_TOOLWINDOW, 0);
        HwndSource.FromHwnd(_hwnd)?.AddHook(WndProc);
        UpdateMouseInteraction();
    }

    private static IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == NativeMethods.WM_MOUSEACTIVATE)
        {
            // Click hoặc kéo panel không lấy focus của app người dùng đang gõ.
            handled = true;
            return new IntPtr(NativeMethods.MA_NOACTIVATE);
        }
        return IntPtr.Zero;
    }

    /// <summary>Chỉ nhận chuột khi chuột ở trên header, hoặc khi đã tắt click xuyên qua.</summary>
    private void UpdateMouseInteraction()
    {
        if (_hwnd == IntPtr.Zero) return;
        var transparent = _settings.ClickThrough && !IsCursorOverHeader();
        if (transparent == _isTransparent) return;
        _isTransparent = transparent;
        NativeMethods.SetExtendedStyle(_hwnd,
            transparent ? NativeMethods.WS_EX_TRANSPARENT : 0,
            transparent ? 0 : NativeMethods.WS_EX_TRANSPARENT);
    }

    private bool IsCursorOverHeader()
    {
        if (!IsVisible || !NativeMethods.GetCursorPos(out var cursor) || !NativeMethods.GetWindowRect(_hwnd, out var r)) return false;
        var scale = NativeMethods.GetDpiForWindow(_hwnd) / 96.0;
        var panel = new Core.Panel.Rect(r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top);
        return PanelPlacement.HeaderRect(panel, scale).Contains(new CorePoint(cursor.X, cursor.Y));
    }

    /// <summary>Timer theo dõi chuột chỉ chạy khi cần: panel đang hiện và click xuyên qua đang bật.</summary>
    private void UpdateMouseTimer()
    {
        if (IsVisible && _settings.ClickThrough) _mouseTimer.Start();
        else _mouseTimer.Stop();
        UpdateMouseInteraction();
    }

    private void BeginDrag(MouseButtonEventArgs e)
    {
        if (e.ButtonState != MouseButtonState.Pressed) return;
        try
        {
            DragMove();
        }
        catch (InvalidOperationException)
        {
            return;
        }
        // Kéo xong: lưu góc trên trái (pixel vật lý) làm vị trí đã kéo.
        if (NativeMethods.GetWindowRect(_hwnd, out var r))
            _settings.CustomTopLeft = new CorePoint(r.Left, r.Top);
        Relayout();
    }

    // ---- Vị trí ----

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(PanelSettings.BackgroundOpacity):
                ApplyColors();
                break;
            case nameof(PanelSettings.ClickThrough):
                ApplyColors();
                UpdateMouseTimer();
                break;
            case nameof(PanelSettings.Width):
                Width = _settings.Width;
                ScheduleRelayout();
                break;
            case nameof(PanelSettings.Corner):
            case nameof(PanelSettings.CustomTopLeft):
                ScheduleRelayout();
                break;
        }
    }

    private void OnDisplaySettingsChanged(object? sender, EventArgs e) => Dispatcher.BeginInvoke(ScheduleRelayout);

    /// <summary>Gom nhiều lần đổi kích thước thành một lần đặt lại vị trí.</summary>
    private void ScheduleRelayout()
    {
        if (_relayoutScheduled) return;
        _relayoutScheduled = true;
        Dispatcher.BeginInvoke(DispatcherPriority.Render, () =>
        {
            _relayoutScheduled = false;
            Relayout();
        });
    }

    /// <summary>
    /// Đặt panel theo vị trí đã kéo (nếu có) hoặc góc đã chọn, trong vùng làm việc của màn hình
    /// (không đè taskbar), cách mép 20 DIP. Panel cao lên thì được dời vào trong.
    /// </summary>
    private void Relayout()
    {
        if (_hwnd == IntPtr.Zero || _applyingLayout) return;

        var monitor = _settings.CustomTopLeft is { } p
            ? NativeMethods.MonitorFromPoint(new NativeMethods.POINT { X = (int)p.X, Y = (int)p.Y }, NativeMethods.MONITOR_DEFAULTTONEAREST)
            : NativeMethods.MonitorFromPoint(default, NativeMethods.MONITOR_DEFAULTTOPRIMARY);
        var (work, scale) = NativeMethods.MonitorWorkArea(monitor);

        // Không bao giờ cao hơn vùng làm việc.
        MaxHeight = Math.Max(60, work.Height / scale - 2 * PanelLayout.DefaultMargin);

        var target = PanelPlacement.Compute(
            _settings.Corner, _settings.CustomTopLeft, new CoreSize(_settings.Width, Math.Max(ActualHeight, 60)), work, scale);
        if (!NativeMethods.GetWindowRect(_hwnd, out var current) ||
            current.Left != (int)target.X || current.Top != (int)target.Y)
        {
            _applyingLayout = true;
            NativeMethods.SetWindowPos(_hwnd, NativeMethods.HWND_TOPMOST, (int)Math.Round(target.X), (int)Math.Round(target.Y), 0, 0,
                NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOACTIVATE);
            _applyingLayout = false;
        }
    }

    protected override void OnClosed(EventArgs e)
    {
        SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
        _mouseTimer.Stop();
        base.OnClosed(e);
    }
}
