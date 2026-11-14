using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace Grammar.App;

/// <summary>
/// App khay hệ thống, không có cửa sổ chính (ShutdownMode = OnExplicitShutdown).
/// Chỉ chạy một bản: bản chạy sau báo cho bản đang chạy hiện panel rồi thoát
/// (spec checker-window: "Chỉ một bản app chạy trên Windows").
/// </summary>
public partial class App : Application
{
    private const string MutexName = @"Local\Grammar.SingleInstance";
    private const string ShowPanelEventName = @"Local\Grammar.ShowPanel";

    private Mutex? _mutex;
    private EventWaitHandle? _showPanel;
    private RegisteredWaitHandle? _showPanelWait;
    private AppController? _controller;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _mutex = new Mutex(initiallyOwned: true, MutexName, out var isFirst);
        if (!isFirst)
        {
            if (EventWaitHandle.TryOpenExisting(ShowPanelEventName, out var other))
            {
                using (other) other.Set();
            }
            Shutdown();
            return;
        }

        DispatcherUnhandledException += OnUnhandledException;
        TaskScheduler.UnobservedTaskException += (_, args) => args.SetObserved();

        _controller = new AppController();
        _showPanel = new EventWaitHandle(false, EventResetMode.AutoReset, ShowPanelEventName);
        _showPanelWait = ThreadPool.RegisterWaitForSingleObject(
            _showPanel, (_, _) => Dispatcher.BeginInvoke(() => _controller?.ShowPanel()), null, Timeout.Infinite, executeOnlyOnce: false);
        _controller.Start();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _showPanelWait?.Unregister(null);
        _showPanel?.Dispose();
        _controller?.Dispose();
        if (_mutex is not null)
        {
            try
            {
                _mutex.ReleaseMutex();
            }
            catch (ApplicationException)
            {
                // Bản chạy sau không sở hữu mutex.
            }
            _mutex.Dispose();
        }
        base.OnExit(e);
    }

    /// <summary>
    /// Lỗi không lường trước: ghi loại lỗi và stack trace (không ghi message, để không bao giờ ghi nội dung người dùng gõ)
    /// vào %LOCALAPPDATA%\Grammar\error.log, rồi chạy tiếp thay vì tắt app.
    /// </summary>
    private static void OnUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        try
        {
            var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Grammar");
            Directory.CreateDirectory(dir);
            File.AppendAllText(Path.Combine(dir, "error.log"),
                $"{DateTime.Now:O} {e.Exception.GetType().FullName}\n{e.Exception.StackTrace}\n\n");
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
        e.Handled = true;
    }
}
