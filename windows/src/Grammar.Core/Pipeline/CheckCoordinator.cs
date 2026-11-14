using System.ComponentModel;
using System.Runtime.CompilerServices;
using Grammar.Core.Diff;
using Grammar.Core.Engine;

namespace Grammar.Core.Pipeline;

/// <summary>
/// Điều phối: debounce, lọc ngôn ngữ, cache, gọi engine, EditGuard.
/// Port của GrammarKit/Pipeline/CheckCoordinator.swift.
/// </summary>
/// <remarks>
/// Giống <c>@MainActor</c> của bản Swift: mọi phương thức phải được gọi trên cùng một thread có
/// <see cref="SynchronizationContext"/> (thread UI của WPF). Các <c>await</c> bên trong quay về đúng thread đó,
/// nên trạng thái không bao giờ bị sửa song song.
/// </remarks>
public sealed class CheckCoordinator : INotifyPropertyChanged
{
    private readonly LanguageGate _gate;
    private readonly EditGuard _editGuard;
    private readonly TimeSpan _debounce;
    private readonly TimeProvider _time;
    private readonly ResultCache<CachedOutcome> _cache = new(200);

    private IGrammarEngine? _engine;
    private string? _engineError;
    private CancellationTokenSource? _pendingCancellation;
    private Task _pendingTask = Task.CompletedTask;

    private CheckState _state;
    private string _sentence = "";
    private TextSource _source = TextSource.FocusedField;

    private abstract record CachedOutcome
    {
        public sealed record Unchanged : CachedOutcome;
        public sealed record Fixed(string Corrected) : CachedOutcome;
        public sealed record Rewritten : CachedOutcome;
    }

    public CheckCoordinator(
        IGrammarEngine? engine = null,
        LanguageGate? gate = null,
        EditGuard? editGuard = null,
        TimeSpan? debounce = null,
        TimeProvider? timeProvider = null)
    {
        _engine = engine;
        _gate = gate ?? new LanguageGate();
        _editGuard = editGuard ?? new EditGuard();
        _debounce = debounce ?? TimeSpan.FromMilliseconds(700);
        _time = timeProvider ?? TimeProvider.System;
        _state = engine is null ? CheckState.LoadingModelState : CheckState.IdleState;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public CheckState State
    {
        get => _state;
        private set => Set(ref _state, value);
    }

    /// <summary>Câu đang hiển thị ở phần trên của panel.</summary>
    public string Sentence
    {
        get => _sentence;
        private set => Set(ref _sentence, value);
    }

    public TextSource Source
    {
        get => _source;
        private set => Set(ref _source, value);
    }

    public bool IsPaused { get; set; }

    /// <summary>Số lần thực sự gọi engine (dùng cho test).</summary>
    public int EngineCallCount { get; private set; }

    /// <summary>Bắt đầu nạp (hoặc nạp lại) model: chưa kiểm tra được cho tới khi <see cref="SetEngine"/>.</summary>
    public void BeginLoadingModel()
    {
        _pendingCancellation?.Cancel();
        _engine = null;
        _engineError = null;
        State = CheckState.LoadingModelState;
    }

    public void SetEngine(IGrammarEngine engine)
    {
        _engine = engine;
        _engineError = null;
        if (State is CheckState.LoadingModel)
        {
            if (Sentence.Length == 0) State = CheckState.IdleState;
            else Submit(Sentence, Source, immediately: true);
        }
    }

    public void SetEngineError(string message)
    {
        _engine = null;
        _engineError = message;
        State = new CheckState.ModelError(message);
    }

    /// <summary>Nhận câu mới. Chờ debounce rồi mới kiểm tra, câu đến sau huỷ câu trước.</summary>
    public void Submit(string newSentence, TextSource source, bool immediately = false)
    {
        if (IsPaused && source == TextSource.FocusedField) return;

        var trimmed = newSentence.Trim();
        if (trimmed == Sentence && !immediately && State is not CheckState.Idle and not CheckState.LoadingModel) return;

        Sentence = trimmed;
        Source = source;
        _pendingCancellation?.Cancel();
        var cancellation = _pendingCancellation = new CancellationTokenSource();

        var delay = immediately ? TimeSpan.Zero : _debounce;
        _pendingTask = RunAfterDelayAsync(trimmed, delay, cancellation.Token);
    }

    /// <summary>Đợi lượt kiểm tra hiện tại xong (dùng cho test).</summary>
    public Task WaitForPendingCheckAsync() => _pendingTask;

    private async Task RunAfterDelayAsync(string text, TimeSpan delay, CancellationToken token)
    {
        if (delay > TimeSpan.Zero)
        {
            try
            {
                await Task.Delay(delay, _time, token);
            }
            catch (OperationCanceledException)
            {
                return;
            }
        }
        if (token.IsCancellationRequested) return;
        await RunAsync(text, token);
    }

    private async Task RunAsync(string text, CancellationToken token)
    {
        if (text != Sentence) return;

        if (text.Length == 0)
        {
            State = CheckState.IdleState;
            return;
        }

        switch (_gate.Evaluate(text))
        {
            case LanguageVerdict.TooShort:
                State = CheckState.IdleState;
                return;
            case LanguageVerdict.NotEnglish:
                State = new CheckState.NotEnglish(text);
                return;
        }

        if (_cache.TryGetValue(text, out var cached))
        {
            Apply(cached, text);
            return;
        }

        if (_engine is not { } engine)
        {
            State = _engineError is { } error ? new CheckState.ModelError(error) : CheckState.LoadingModelState;
            return;
        }

        State = new CheckState.Checking(text);
        EngineCallCount++;
        try
        {
            // Bỏ qua khác biệt viết hoa/viết thường và dấu câu cuối câu.
            var raw = await engine.CorrectAsync(text, token);
            var corrected = CorrectionNormalizer.Reconcile(text, raw);
            // Câu đã thay đổi trong lúc đang kiểm tra -> bỏ kết quả cũ.
            if (token.IsCancellationRequested || text != Sentence) return;

            var diff = new WordDiff(text, corrected);
            CachedOutcome outcome = _editGuard.Evaluate(diff) switch
            {
                EditVerdict.Unchanged => new CachedOutcome.Unchanged(),
                EditVerdict.Accepted => new CachedOutcome.Fixed(corrected),
                _ => new CachedOutcome.Rewritten(),
            };
            _cache.Insert(outcome, text);
            Apply(outcome, text);
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception error)
        {
            if (text != Sentence) return;
            State = new CheckState.ModelError(error.Message);
        }
    }

    private void Apply(CachedOutcome outcome, string text) =>
        State = outcome switch
        {
            CachedOutcome.Unchanged => new CheckState.Ok(text),
            CachedOutcome.Fixed f => new CheckState.Corrected(new WordDiff(text, f.Corrected)),
            _ => new CheckState.Uncertain(text),
        };

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
