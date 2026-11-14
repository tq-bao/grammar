using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using Grammar.Core.Engine;
using Grammar.Core.Panel;

namespace Grammar.App.UI;

/// <summary>
/// Màn hình Cài đặt (spec checker-window: "Màn hình Cài đặt"). Bản Windows của SettingsView.swift,
/// thêm mục chọn model và dòng cho biết model đang chạy trên GPU hay CPU. Mọi thay đổi áp dụng ngay.
/// </summary>
internal sealed class SettingsWindow : Window
{
    private readonly PanelSettings _settings;
    private readonly AppController _app;
    private readonly Slider _opacity = new() { Minimum = 0, Maximum = 100, TickFrequency = 5, IsSnapToTickEnabled = true, Width = 220 };
    private readonly TextBlock _opacityLabel = new() { Width = 44, TextAlignment = TextAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
    private readonly CheckBox _clickThrough = new() { Content = "Click xuyên qua panel" };
    private readonly ComboBox _corner = new() { Width = 160 };
    private readonly Button _resetPosition = new() { Content = "Về góc đã chọn", Padding = new Thickness(10, 3, 10, 3), HorizontalAlignment = HorizontalAlignment.Left };
    private readonly Slider _width = new() { Minimum = PanelSettings.MinWidth, Maximum = PanelSettings.MaxWidth, TickFrequency = 10, IsSnapToTickEnabled = true, Width = 220 };
    private readonly TextBlock _widthLabel = new() { Width = 44, TextAlignment = TextAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
    private readonly ComboBox _model = new() { MinWidth = 280 };
    private readonly TextBlock _backend = new() { Margin = new Thickness(0, 4, 0, 0) };
    private bool _updating;

    private static readonly (PanelCorner Corner, string Name)[] Corners =
    [
        (PanelCorner.TopRight, "Trên phải"),
        (PanelCorner.TopLeft, "Trên trái"),
        (PanelCorner.BottomRight, "Dưới phải"),
        (PanelCorner.BottomLeft, "Dưới trái"),
    ];

    public SettingsWindow(PanelSettings settings, AppController app)
    {
        _settings = settings;
        _app = app;
        Title = "Grammar – Cài đặt";
        SizeToContent = SizeToContent.WidthAndHeight;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        ShowInTaskbar = true;

        foreach (var (_, name) in Corners) _corner.Items.Add(name);

        _opacity.ValueChanged += (_, e) => { if (!_updating) _settings.BackgroundOpacity = e.NewValue / 100; };
        _width.ValueChanged += (_, e) => { if (!_updating) _settings.Width = e.NewValue; };
        _clickThrough.Click += (_, _) => _settings.ClickThrough = _clickThrough.IsChecked == true;
        _corner.SelectionChanged += (_, _) =>
        {
            // Chọn một góc thì bỏ vị trí đã kéo (spec "Vị trí panel do người dùng kéo").
            if (!_updating && _corner.SelectedIndex >= 0) _settings.Corner = Corners[_corner.SelectedIndex].Corner;
        };
        _resetPosition.Click += (_, _) => _settings.ResetPosition();
        _model.SelectionChanged += (_, _) =>
        {
            if (!_updating && _model.SelectedItem is string name) _app.SelectModel(name);
        };

        Content = new StackPanel
        {
            Margin = new Thickness(20),
            Children =
            {
                Row("Độ mờ nền", new StackPanel { Orientation = Orientation.Horizontal, Children = { _opacity, _opacityLabel } }),
                Row("", _clickThrough),
                Hint("Tắt để kéo panel ở bất kỳ đâu (panel hiện viền nét đứt). Kéo xong thì bật lại."),
                Row("Góc màn hình", _corner),
                Row("", _resetPosition),
                Row("Độ rộng panel", new StackPanel { Orientation = Orientation.Horizontal, Children = { _width, _widthLabel } }),
                new Separator { Margin = new Thickness(0, 12, 0, 12) },
                Row("Model", _model),
                Row("", _backend),
                Hint("Model 7B chính xác hơn. Máy không có GPU hoặc ít RAM có thể chọn model 3B cho nhanh hơn."),
            },
        };

        _settings.PropertyChanged += OnSettingsChanged;
        _app.PropertyChanged += OnAppChanged;
        Closed += (_, _) =>
        {
            _settings.PropertyChanged -= OnSettingsChanged;
            _app.PropertyChanged -= OnAppChanged;
        };
        Refresh();
    }

    private static UIElement Row(string label, UIElement control)
    {
        var grid = new Grid { Margin = new Thickness(0, 4, 0, 4) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(120) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var text = new TextBlock { Text = label, VerticalAlignment = VerticalAlignment.Center };
        Grid.SetColumn(control, 1);
        grid.Children.Add(text);
        grid.Children.Add(control);
        return grid;
    }

    private static UIElement Hint(string text)
    {
        var block = new TextBlock { Text = text, TextWrapping = TextWrapping.Wrap, MaxWidth = 380, Margin = new Thickness(120, 0, 0, 6), FontSize = 11 };
        block.SetResourceReference(TextBlock.ForegroundProperty, SystemColors.GrayTextBrushKey);
        return block;
    }

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e) => Refresh();

    private void OnAppChanged(object? sender, PropertyChangedEventArgs e) => Refresh();

    private void Refresh()
    {
        _updating = true;
        try
        {
            _opacity.Value = Math.Round(_settings.BackgroundOpacity * 100);
            _opacityLabel.Text = $"{_opacity.Value:0}%";
            _clickThrough.IsChecked = _settings.ClickThrough;
            _corner.SelectedIndex = Array.FindIndex(Corners, c => c.Corner == _settings.Corner);
            // Nút "Về góc đã chọn" chỉ có khi panel đang ở vị trí đã kéo.
            _resetPosition.Visibility = _settings.CustomTopLeft is null ? Visibility.Collapsed : Visibility.Visible;
            _width.Value = _settings.Width;
            _widthLabel.Text = $"{_settings.Width:0}";

            var models = ModelLocator.AvailableModels(ModelLocator.DefaultModelsDirectory);
            _model.ItemsSource = models;
            _model.SelectedItem = _app.CurrentModelName is { } current && models.Contains(current) ? current : null;
            _model.IsEnabled = models.Count > 1;
            _backend.Text = _app.BackendDescription;
        }
        finally
        {
            _updating = false;
        }
    }
}
