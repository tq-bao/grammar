using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Grammar.Core.Panel;

/// <summary>Nơi lưu file cài đặt. Tách ra để test không đụng tới đĩa.</summary>
public interface ISettingsStore
{
    string? Load();
    void Save(string json);
}

/// <summary>Lưu cài đặt ở <c>%APPDATA%\Grammar\settings.json</c> (ghi ra file tạm rồi đổi tên, tránh hỏng file).</summary>
public sealed class FileSettingsStore(string path) : ISettingsStore
{
    public static string DefaultPath =>
        System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Grammar", "settings.json");

    public string FilePath { get; } = path;

    public string? Load()
    {
        try
        {
            return File.Exists(FilePath) ? File.ReadAllText(FilePath) : null;
        }
        catch (IOException)
        {
            return null;
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }
    }

    public void Save(string json)
    {
        try
        {
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(FilePath)!);
            var temp = FilePath + ".tmp";
            File.WriteAllText(temp, json);
            File.Move(temp, FilePath, overwrite: true);
        }
        catch (IOException)
        {
            // Không lưu được thì vẫn dùng giá trị trong bộ nhớ; lần sau dùng mặc định.
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}

/// <summary>Bộ nhớ tạm, dùng cho test.</summary>
public sealed class MemorySettingsStore(string? json = null) : ISettingsStore
{
    public string? Json { get; private set; } = json;
    public string? Load() => Json;
    public void Save(string json) => Json = json;
}

/// <summary>
/// Cài đặt hiển thị của panel. Port của GrammarKit/Panel/PanelSettings.swift, lưu bằng JSON thay cho UserDefaults.
/// Mỗi thay đổi được kẹp vào khoảng hợp lệ và ghi xuống ngay. Giá trị sai hoặc thiếu thì dùng mặc định.
/// </summary>
public sealed class PanelSettings : INotifyPropertyChanged
{
    public const double MinOpacity = 0;
    public const double MaxOpacity = 1;
    public const double MinWidth = 320;
    public const double MaxWidth = 700;
    public const double DefaultOpacity = 0.75;
    public const PanelCorner DefaultCorner = PanelCorner.TopRight;
    public const double DefaultWidth = 460;
    public const bool DefaultClickThrough = true;

    /// <summary>Tên trường trong file JSON.</summary>
    public static class Key
    {
        public const string Opacity = "backgroundOpacity";
        public const string Corner = "corner";
        public const string Width = "width";
        public const string ClickThrough = "clickThrough";
        public const string CustomTopLeft = "customTopLeft";
        public const string Model = "model";
    }

    private readonly ISettingsStore _store;
    private double _backgroundOpacity;
    private PanelCorner _corner;
    private double _width;
    private bool _clickThrough;
    private Point? _customTopLeft;
    private string? _model;

    public PanelSettings(ISettingsStore store)
    {
        _store = store;
        JsonObject? json = null;
        try
        {
            json = store.Load() is { } text ? JsonNode.Parse(text) as JsonObject : null;
        }
        catch (JsonException)
        {
            // File hỏng: dùng toàn bộ mặc định.
        }

        _backgroundOpacity = Clamp(ReadDouble(json, Key.Opacity), MinOpacity, MaxOpacity, DefaultOpacity);
        _corner = ReadCorner(json) ?? DefaultCorner;
        _width = Clamp(ReadDouble(json, Key.Width), MinWidth, MaxWidth, DefaultWidth);
        _clickThrough = ReadBool(json, Key.ClickThrough) ?? DefaultClickThrough;
        _customTopLeft = ReadPoint(json);
        _model = ReadString(json, Key.Model);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>Độ mờ nền: 0 = trong suốt hoàn toàn, 1 = đục.</summary>
    public double BackgroundOpacity
    {
        get => _backgroundOpacity;
        set => SetAndSave(ref _backgroundOpacity, Clamp(value, MinOpacity, MaxOpacity, DefaultOpacity));
    }

    /// <summary>Chọn góc thì bỏ vị trí đã kéo, panel về góc đó.</summary>
    public PanelCorner Corner
    {
        get => _corner;
        set
        {
            var changed = _corner != value;
            _corner = value;
            _customTopLeft = null;
            Save();
            if (changed) OnChanged();
            OnChanged(nameof(CustomTopLeft));
        }
    }

    /// <summary>Click xuyên qua panel. Tắt để kéo panel đi chỗ khác.</summary>
    public bool ClickThrough
    {
        get => _clickThrough;
        set => SetAndSave(ref _clickThrough, value);
    }

    /// <summary>
    /// Góc trên trái của panel do người dùng kéo, bằng pixel vật lý của màn hình ảo (xem <see cref="PanelPlacement"/>).
    /// <c>null</c> = đặt theo <see cref="Corner"/>.
    /// </summary>
    public Point? CustomTopLeft
    {
        get => _customTopLeft;
        set => SetAndSave(ref _customTopLeft, value is { } p && double.IsFinite(p.X) && double.IsFinite(p.Y) ? p : null);
    }

    /// <summary>Độ rộng panel (DIP).</summary>
    public double Width
    {
        get => _width;
        set => SetAndSave(ref _width, Clamp(value, MinWidth, MaxWidth, DefaultWidth));
    }

    /// <summary>Tên file model đã chọn trong thư mục Models (chỉ có ở bản Windows). <c>null</c> = model mặc định.</summary>
    public string? Model
    {
        get => _model;
        set => SetAndSave(ref _model, string.IsNullOrWhiteSpace(value) ? null : value);
    }

    /// <summary>Bỏ vị trí đã kéo, panel về góc đang chọn.</summary>
    public void ResetPosition() => CustomTopLeft = null;

    public void ResetToDefaults()
    {
        BackgroundOpacity = DefaultOpacity;
        Corner = DefaultCorner;
        Width = DefaultWidth;
        ClickThrough = DefaultClickThrough;
        CustomTopLeft = null;
    }

    private void Save()
    {
        var json = new JsonObject
        {
            [Key.Opacity] = _backgroundOpacity,
            [Key.Corner] = CornerName(_corner),
            [Key.Width] = _width,
            [Key.ClickThrough] = _clickThrough,
            [Key.CustomTopLeft] = _customTopLeft is { } p ? new JsonArray(p.X, p.Y) : null,
            [Key.Model] = _model,
        };
        _store.Save(json.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }

    private void SetAndSave<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        Save();
        OnChanged(name);
    }

    private void OnChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    // ---- Đọc JSON: mỗi trường kiểm tra riêng, sai kiểu thì bỏ qua ----

    private static string CornerName(PanelCorner c) => c switch
    {
        PanelCorner.TopRight => "topRight",
        PanelCorner.TopLeft => "topLeft",
        PanelCorner.BottomRight => "bottomRight",
        _ => "bottomLeft",
    };

    private static PanelCorner? ReadCorner(JsonObject? json) => ReadString(json, Key.Corner) switch
    {
        "topRight" => PanelCorner.TopRight,
        "topLeft" => PanelCorner.TopLeft,
        "bottomRight" => PanelCorner.BottomRight,
        "bottomLeft" => PanelCorner.BottomLeft,
        _ => null,
    };

    private static double? ReadDouble(JsonObject? json, string key) =>
        json?[key] is JsonValue v && v.TryGetValue<double>(out var d) ? d : null;

    private static bool? ReadBool(JsonObject? json, string key) =>
        json?[key] is JsonValue v && v.TryGetValue<bool>(out var b) ? b : null;

    private static string? ReadString(JsonObject? json, string key) =>
        json?[key] is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;

    private static Point? ReadPoint(JsonObject? json)
    {
        if (json?[Key.CustomTopLeft] is not JsonArray { Count: 2 } array) return null;
        if (array[0] is not JsonValue a || !a.TryGetValue<double>(out var x)) return null;
        if (array[1] is not JsonValue b || !b.TryGetValue<double>(out var y)) return null;
        return double.IsFinite(x) && double.IsFinite(y) ? new Point(x, y) : null;
    }

    private static double Clamp(double? value, double min, double max, double fallback) =>
        value is { } v && double.IsFinite(v) ? Math.Clamp(v, min, max) : fallback;
}
