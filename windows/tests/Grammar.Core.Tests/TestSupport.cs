using System.Collections.Concurrent;
using Grammar.Core.Engine;

namespace Grammar.Core.Tests;

/// <summary>
/// Chạy code async trên một thread riêng có <see cref="SynchronizationContext"/>, giống thread UI của WPF:
/// mọi continuation quay về đúng thread này, theo thứ tự.
/// </summary>
internal static class UiThread
{
    private sealed class QueueContext : SynchronizationContext
    {
        public readonly BlockingCollection<(SendOrPostCallback, object?)> Queue = new();
        public override void Post(SendOrPostCallback d, object? state) => Queue.Add((d, state));
        public override void Send(SendOrPostCallback d, object? state) => throw new NotSupportedException();
    }

    public static void Run(Func<Task> body)
    {
        Exception? failure = null;
        var thread = new Thread(() =>
        {
            var context = new QueueContext();
            SynchronizationContext.SetSynchronizationContext(context);
            var task = body();
            task.ContinueWith(_ => context.Queue.CompleteAdding(), TaskScheduler.Default);
            foreach (var (callback, state) in context.Queue.GetConsumingEnumerable()) callback(state);
            try { task.GetAwaiter().GetResult(); }
            catch (Exception e) { failure = e; }
        });
        thread.Start();
        if (!thread.Join(TimeSpan.FromSeconds(10))) throw new TimeoutException("Test UI thread bị treo.");
        if (failure is not null) System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(failure).Throw();
    }

    /// <summary>Nhường lượt để các continuation đang chờ trong hàng đợi chạy hết.</summary>
    public static async Task Pump(int rounds = 5)
    {
        for (var i = 0; i < rounds; i++) await Task.Yield();
    }
}

/// <summary>
/// Engine giả: trả kết quả theo bảng. Khi <see cref="Hold"/> bật, mỗi lời gọi chờ tới khi test gọi
/// <see cref="Release"/>, để mô phỏng engine đang chạy dở.
/// </summary>
internal sealed class FakeEngine(Dictionary<string, string> answers) : IGrammarEngine
{
    private readonly Dictionary<string, TaskCompletionSource> _gates = new();

    public List<string> Calls { get; } = [];
    public bool Hold { get; set; }
    public Exception? Throw { get; set; }

    public async Task<string> CorrectAsync(string sentence, CancellationToken cancellationToken = default)
    {
        Calls.Add(sentence);
        if (Throw is not null) throw Throw;
        if (Hold)
        {
            var gate = _gates[sentence] = new TaskCompletionSource();
            await gate.Task;
        }
        return answers.TryGetValue(sentence, out var answer) ? answer : sentence;
    }

    public void Release(string sentence) => _gates[sentence].SetResult();
}
