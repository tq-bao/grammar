using System.Runtime.InteropServices;
using Grammar.Core.Capture;
using Interop.UIAutomationClient;

namespace Grammar.App.Capture;

/// <summary>
/// Theo dõi ô nhập liệu đang được focus ở app khác qua UI Automation. Bản Windows của AXTextCapture.swift.
/// </summary>
/// <remarks>
/// <list type="bullet">
/// <item>Nghe focus đổi (toàn hệ thống), và TextChanged / TextSelectionChanged trên ô đang focus.</item>
/// <item>Không nhận được event nào (nhiều app chỉ hỗ trợ ValuePattern) thì hỏi lại mỗi 500 ms, sau 1 giây im lặng.</item>
/// <item>Cách đọc và bộ lọc (ô mật khẩu, chính app, app chạy quyền admin) nằm ở <see cref="FocusedFieldReader"/>.</item>
/// </list>
/// Kết quả được đưa về thread UI qua <see cref="SynchronizationContext"/> lấy lúc <see cref="Start"/>.
/// </remarks>
internal sealed class UiaTextCapture : IDisposable
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(500);
    private static readonly TimeSpan QuietBeforePolling = TimeSpan.FromSeconds(1);
    /// <summary>Giới hạn số ký tự đọc mỗi lần, tránh đọc cả trang rất dài sau mỗi phím gõ.</summary>
    private const int MaxTextLength = 20_000;

    private readonly UiaThread _uia = new();
    private readonly int _ownProcessId = Environment.ProcessId;
    private readonly ChangeFilter _changes = new();
    private readonly FocusHandler _focusHandler;
    private readonly TextHandler _textHandler;

    // Các trường dưới chỉ được dùng trên thread UIA.
    private IUIAutomationElement? _focused;
    private bool _textHandlersAttached;
    private DateTime _lastEvent = DateTime.MinValue;

    private SynchronizationContext? _ui;
    private Timer? _pollTimer;
    private volatile bool _running;

    /// <summary>Gọi trên thread UI khi nội dung hoặc vị trí con trỏ của ô đang focus thay đổi.</summary>
    public event Action<string, int?>? Changed;

    public UiaTextCapture()
    {
        _focusHandler = new FocusHandler(this);
        _textHandler = new TextHandler(this);
    }

    public bool IsRunning => _running;

    public void Start()
    {
        if (_running) return;
        _running = true;
        _ui = SynchronizationContext.Current;
        _uia.Post(() =>
        {
            _changes.Reset();
            _uia.Automation.AddFocusChangedEventHandler(null, _focusHandler);
            UpdateFocusedElement(_uia.Automation.GetFocusedElement());
        });
        _pollTimer = new Timer(_ => _uia.Post(PollIfNeeded), null, PollInterval, PollInterval);
    }

    public void Stop()
    {
        if (!_running) return;
        _running = false;
        _pollTimer?.Dispose();
        _pollTimer = null;
        _uia.Post(() =>
        {
            DetachTextHandlers();
            _focused = null;
            _uia.Automation.RemoveFocusChangedEventHandler(_focusHandler);
        });
    }

    // ---- Thread UIA ----

    private void UpdateFocusedElement(IUIAutomationElement? element)
    {
        if (!_running) return;
        DetachTextHandlers();
        _focused = element;
        _lastEvent = DateTime.MinValue;
        _changes.Reset();
        if (element is null) return;

        // Không đăng ký event trên cửa sổ của chính app (spec: không đọc chính app).
        if (SafeProcessId(element) == _ownProcessId) return;
        try
        {
            if (element.GetCurrentPattern(UIA_PatternIds.UIA_TextPatternId) is not null)
            {
                foreach (var id in TextEvents)
                    _uia.Automation.AddAutomationEventHandler(id, element, TreeScope.TreeScope_Element, null, _textHandler);
                _textHandlersAttached = true;
            }
        }
        catch (COMException)
        {
            // App không cho đăng ký event: vẫn còn poll.
        }
        Read();
    }

    private void DetachTextHandlers()
    {
        if (!_textHandlersAttached || _focused is null) return;
        _textHandlersAttached = false;
        foreach (var id in TextEvents)
        {
            try
            {
                _uia.Automation.RemoveAutomationEventHandler(id, _focused, _textHandler);
            }
            catch (COMException)
            {
            }
        }
    }

    private static readonly int[] TextEvents =
    [
        UIA_EventIds.UIA_Text_TextChangedEventId,
        UIA_EventIds.UIA_Text_TextSelectionChangedEventId,
    ];

    /// <summary>Ô không gửi event thì hỏi lại định kỳ. Có cả trường hợp focus đổi mà app không báo.</summary>
    private void PollIfNeeded()
    {
        if (!_running || DateTime.UtcNow - _lastEvent < QuietBeforePolling) return;
        var current = _uia.Automation.GetFocusedElement();
        if (current is not null && (_focused is null || _uia.Automation.CompareElements(current, _focused) == 0))
        {
            UpdateFocusedElement(current);
            return;
        }
        Read();
    }

    private void Read()
    {
        if (!_running || _focused is not { } element) return;
        if (FocusedFieldReader.Read(Probe(element), _ownProcessId) is not { } text) return;
        if (!_changes.ShouldEmit(text)) return;

        var handler = Changed;
        if (handler is null) return;
        if (_ui is null) handler(text.Text, text.Cursor);
        else _ui.Post(_ => handler(text.Text, text.Cursor), null);
    }

    private static int SafeProcessId(IUIAutomationElement element)
    {
        try
        {
            return element.CurrentProcessId;
        }
        catch (COMException)
        {
            return -1;
        }
    }

    /// <summary>Đọc ô qua UI Automation, mỗi cách đọc là một hàm cho <see cref="FocusedFieldReader"/> chọn.</summary>
    private static FieldProbe Probe(IUIAutomationElement element) => new(
        SafeProcessId(element),
        element.CurrentIsPassword != 0,
        CaretParagraph: () =>
            element.GetCurrentPattern(UIA_PatternIds.UIA_TextPattern2Id) is IUIAutomationTextPattern2 text2
                ? ParagraphAround(text2.GetCaretRange(out _))
                : null,
        SelectionParagraph: () =>
        {
            if (element.GetCurrentPattern(UIA_PatternIds.UIA_TextPatternId) is not IUIAutomationTextPattern text) return null;
            var selection = text.GetSelection();
            return selection is { Length: > 0 } ? ParagraphAround(selection.GetElement(0)) : null;
        },
        Value: () =>
            element.GetCurrentPattern(UIA_PatternIds.UIA_ValuePatternId) is IUIAutomationValuePattern value
                ? Truncate(value.CurrentValue)
                : null);

    /// <summary>
    /// Đoạn văn chứa đầu của <paramref name="caret"/>, và phần từ đầu đoạn tới đó.
    /// Tương đương AXParagraphTextMarkerRangeForTextMarker của bản macOS.
    /// </summary>
    private static (string Paragraph, string Prefix)? ParagraphAround(IUIAutomationTextRange? caret)
    {
        if (caret is null) return null;
        var paragraph = caret.Clone();
        paragraph.ExpandToEnclosingUnit(TextUnit.TextUnit_Paragraph);

        var prefix = paragraph.Clone();
        prefix.MoveEndpointByRange(
            TextPatternRangeEndpoint.TextPatternRangeEndpoint_End, caret, TextPatternRangeEndpoint.TextPatternRangeEndpoint_Start);

        var paragraphText = paragraph.GetText(MaxTextLength);
        var prefixText = prefix.GetText(MaxTextLength);
        return paragraphText is null ? null : (paragraphText, prefixText ?? "");
    }

    private static string? Truncate(string? text) =>
        text is { Length: > MaxTextLength } ? text[^MaxTextLength..] : text;

    public void Dispose()
    {
        Stop();
        _uia.Dispose();
    }

    // ---- Event handler COM: chạy trên thread của UIA, chỉ xếp việc vào UiaThread ----

    [ComVisible(true)]
    private sealed class FocusHandler(UiaTextCapture owner) : IUIAutomationFocusChangedEventHandler
    {
        public void HandleFocusChangedEvent(IUIAutomationElement sender) =>
            owner._uia.Post(() =>
            {
                owner._lastEvent = DateTime.UtcNow;
                owner.UpdateFocusedElement(sender);
            });
    }

    [ComVisible(true)]
    private sealed class TextHandler(UiaTextCapture owner) : IUIAutomationEventHandler
    {
        public void HandleAutomationEvent(IUIAutomationElement sender, int eventId) =>
            owner._uia.Post(() =>
            {
                owner._lastEvent = DateTime.UtcNow;
                owner.Read();
            });
    }
}
