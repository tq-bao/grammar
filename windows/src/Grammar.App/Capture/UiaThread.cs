using System.Collections.Concurrent;
using Interop.UIAutomationClient;

namespace Grammar.App.Capture;

/// <summary>
/// Thread nền riêng (MTA) sở hữu toàn bộ object UI Automation.
/// </summary>
/// <remarks>
/// Theo hướng dẫn của Microsoft, client UIA không được gọi UIA hay xử lý event UIA trên thread có UI,
/// nếu không rất dễ deadlock khi app đích gọi ngược lại. Vì vậy thread UI của WPF không bao giờ gọi UIA:
/// mọi việc được xếp hàng vào thread này. Event handler của UIA (chạy trên thread của UIA) cũng chỉ xếp hàng việc,
/// không gọi UIA trực tiếp.
/// </remarks>
internal sealed class UiaThread : IDisposable
{
    /// <summary>Thời gian chờ tối đa một app trả lời (giống AXUIElementSetMessagingTimeout 0.25 s của bản macOS).</summary>
    private const uint TimeoutMilliseconds = 250;

    private readonly BlockingCollection<Action> _queue = new();
    private readonly Thread _thread;
    private readonly TaskCompletionSource<IUIAutomation> _automation = new(TaskCreationOptions.RunContinuationsAsynchronously);

    public UiaThread()
    {
        _thread = new Thread(Run) { IsBackground = true, Name = "Grammar UI Automation" };
        _thread.SetApartmentState(ApartmentState.MTA);
        _thread.Start();
    }

    /// <summary>Đối tượng UIA. Chỉ được dùng bên trong <see cref="Post"/>.</summary>
    public IUIAutomation Automation => _automation.Task.Result;

    public bool IsCurrentThread => Thread.CurrentThread == _thread;

    /// <summary>Xếp một việc vào thread UIA. Lỗi trong việc đó được nuốt (app đích có thể biến mất bất cứ lúc nào).</summary>
    public void Post(Action work)
    {
        if (!_queue.IsAddingCompleted)
        {
            try
            {
                _queue.Add(work);
            }
            catch (InvalidOperationException)
            {
                // Đã dừng.
            }
        }
    }

    private void Run()
    {
        try
        {
            var automation = new CUIAutomation8();
            if (automation is IUIAutomation2 withTimeouts)
            {
                withTimeouts.ConnectionTimeout = TimeoutMilliseconds;
                withTimeouts.TransactionTimeout = TimeoutMilliseconds;
            }
            _automation.SetResult(automation);
        }
        catch (Exception e)
        {
            _automation.SetException(e);
            return;
        }

        foreach (var work in _queue.GetConsumingEnumerable())
        {
            try
            {
                work();
            }
            catch (Exception)
            {
                // COMException, UIA_E_ELEMENTNOTAVAILABLE, timeout...: bỏ qua lượt này.
            }
        }
    }

    public void Dispose()
    {
        _queue.CompleteAdding();
        _thread.Join(TimeSpan.FromSeconds(2));
    }
}
