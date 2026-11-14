using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Windows;
using Grammar.App.Capture;
using Grammar.App.Tray;
using Grammar.App.UI;
using Grammar.Core.Engine;
using Grammar.Core.Panel;
using Grammar.Core.Pipeline;
using Grammar.Engine;

namespace Grammar.App;

/// <summary>
/// Nối các phần của app: đọc ô đang gõ, pipeline kiểm tra, engine, panel, khay hệ thống, cài đặt.
/// Bản Windows của AppModel.swift. Mọi phương thức chạy trên thread UI của WPF.
/// </summary>
internal sealed class AppController : INotifyPropertyChanged, IDisposable
{
    private readonly UiaTextCapture _capture = new();
    private readonly string _modelsDirectory = ModelLocator.DefaultModelsDirectory;
    private PanelWindow? _panel;
    private TrayIcon? _tray;
    private SettingsWindow? _settingsWindow;
    private LlamaGrammarEngine? _engine;
    private int _loadGeneration;
    private string _backendDescription = "Đang nạp model…";
    private string? _currentModelName;

    public PanelSettings Settings { get; } = new(new FileSettingsStore(FileSettingsStore.DefaultPath));
    public CheckCoordinator Coordinator { get; } = new();

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool IsPanelVisible => _panel?.IsVisible == true;
    public bool IsPaused { get; private set; }

    /// <summary>Có câu sửa để copy (trạng thái "có lỗi").</summary>
    public bool CanCopyCorrection => Coordinator.State is CheckState.Corrected;

    /// <summary>Dòng hiển thị trong Cài đặt: model đang chạy trên GPU hay CPU.</summary>
    public string BackendDescription
    {
        get => _backendDescription;
        private set => Set(ref _backendDescription, value);
    }

    /// <summary>Tên file model đang dùng (hoặc đang nạp).</summary>
    public string? CurrentModelName
    {
        get => _currentModelName;
        private set => Set(ref _currentModelName, value);
    }

    public void Start()
    {
        _capture.Changed += (text, cursor) =>
        {
            if (SentenceExtractor.Sentence(text, cursor) is { } sentence) Coordinator.Submit(sentence, TextSource.FocusedField);
        };

        _panel = new PanelWindow(Settings, Coordinator, () => IsPaused);
        _tray = new TrayIcon(this);
        ShowPanel();
        _ = LoadEngineAsync();
        // Windows không cần cấp quyền như Accessibility trên macOS: theo dõi ngay.
        _capture.Start();
    }

    // ---- Engine ----

    /// <summary>Nạp (hoặc nạp lại) model ở nền. Model cũ được giải phóng trước để không giữ hai model trong RAM.</summary>
    private async Task LoadEngineAsync()
    {
        var generation = ++_loadGeneration;
        Coordinator.BeginLoadingModel();
        BackendDescription = "Đang nạp model…";

        var old = _engine;
        _engine = null;
        if (old is not null) await Task.Run(old.Dispose);

        try
        {
            var path = ModelLocator.Locate(_modelsDirectory, Settings.Model);
            CurrentModelName = Path.GetFileName(path);
            var loaded = await Task.Run(() => BackendSelector.LoadAsync(path));
            if (generation != _loadGeneration)
            {
                // Người dùng đã chọn model khác trong lúc đang nạp.
                loaded.Engine.Dispose();
                return;
            }
            _engine = loaded.Engine;
            Coordinator.SetEngine(loaded.Engine);
            BackendDescription = loaded.Backend == ComputeBackend.Gpu
                ? "Đang chạy trên: GPU"
                : loaded.GpuFallbackReason is null ? "Đang chạy trên: CPU" : "Đang chạy trên: CPU (GPU không dùng được)";
        }
        catch (Exception e)
        {
            if (generation != _loadGeneration) return;
            Coordinator.SetEngineError(e.Message);
            BackendDescription = "Chưa nạp được model";
        }
    }

    /// <summary>Chọn model trong Cài đặt: lưu lựa chọn và nạp lại, không cần khởi động lại app.</summary>
    public void SelectModel(string fileName)
    {
        if (fileName == CurrentModelName) return;
        Settings.Model = fileName;
        _ = LoadEngineAsync();
    }

    // ---- Panel, tạm dừng, copy ----

    public void TogglePanel()
    {
        if (IsPanelVisible) HidePanel();
        else ShowPanel();
    }

    public void ShowPanel() => _panel?.ShowPanel();

    public void HidePanel() => _panel?.Hide();

    public void TogglePause()
    {
        IsPaused = !IsPaused;
        Coordinator.IsPaused = IsPaused;
        if (IsPaused) _capture.Stop();
        else _capture.Start();
        _panel?.Refresh();
    }

    /// <summary>Copy câu đã sửa vào clipboard. Không làm gì nếu không có câu sửa.</summary>
    public void CopyCorrection()
    {
        if (Coordinator.State is not CheckState.Corrected corrected) return;
        // Clipboard có thể đang bị app khác giữ (CLIPBRD_E_CANT_OPEN): thử lại vài lần.
        for (var attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                Clipboard.SetText(corrected.Diff.Corrected);
                return;
            }
            catch (COMException)
            {
                Thread.Sleep(50);
            }
            catch (ExternalException)
            {
                Thread.Sleep(50);
            }
        }
    }

    public void OpenSettings()
    {
        if (_settingsWindow is null)
        {
            _settingsWindow = new SettingsWindow(Settings, this);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
            _settingsWindow.Show();
        }
        _settingsWindow.Activate();
    }

    public void Quit() => Application.Current.Shutdown();

    public void Dispose()
    {
        _capture.Dispose();
        _tray?.Dispose();
        _engine?.Dispose();
    }

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
