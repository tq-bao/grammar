// Grammar.Probe: chẩn đoán (chỉ đọc) một app trả về gì qua UI Automation cho ô đang gõ.
// Bản Windows của scripts/ax-probe.swift.
//
//   Grammar.Probe.exe             chờ 5 giây rồi đọc ô đang focus
//   Grammar.Probe.exe 10          chờ 10 giây
//   Grammar.Probe.exe slack       chờ tới khi cửa sổ phía trước thuộc process "slack", đợi thêm 3 giây rồi đọc
//
// Chạy lệnh, chuyển sang app cần kiểm tra và đặt con trỏ vào ô đang gõ. Probe in ra:
//   - process, loại ô, framework, các pattern ô hỗ trợ;
//   - đoạn văn và vị trí con trỏ theo từng cách đọc mà Grammar dùng (TextPattern2, TextPattern, ValuePattern);
//   - câu mà Grammar sẽ kiểm tra.
// Probe không thay đổi gì, không lưu nội dung, và không in nội dung ô mật khẩu.

using System.Diagnostics;
using System.Runtime.InteropServices;
using Grammar.Core.Capture;
using Grammar.Core.Pipeline;
using Interop.UIAutomationClient;

Console.OutputEncoding = System.Text.Encoding.UTF8;
var argument = args.Length > 0 ? args[0] : "5";

if (int.TryParse(argument, out var seconds))
{
    Console.WriteLine($"Chuyển sang app cần kiểm tra và đặt con trỏ vào ô đang gõ. Đọc sau {seconds} giây…");
    Thread.Sleep(TimeSpan.FromSeconds(seconds));
}
else
{
    Console.WriteLine($"Chờ cửa sổ của process \"{argument}\" được đưa lên trước…");
    while (!string.Equals(ForegroundProcessName(), argument, StringComparison.OrdinalIgnoreCase)) Thread.Sleep(300);
    Console.WriteLine("Đặt con trỏ vào ô đang gõ, đọc sau 3 giây…");
    Thread.Sleep(TimeSpan.FromSeconds(3));
}

// UIA phải chạy trên thread MTA, giống Grammar.
var thread = new Thread(Probe);
thread.SetApartmentState(ApartmentState.MTA);
thread.Start();
thread.Join();
return;

static void Probe()
{
    var automation = new CUIAutomation8();
    if (automation is IUIAutomation2 a2)
    {
        a2.ConnectionTimeout = 1000;
        a2.TransactionTimeout = 1000;
    }

    IUIAutomationElement element;
    try
    {
        element = automation.GetFocusedElement();
    }
    catch (COMException e)
    {
        Console.WriteLine($"Không lấy được ô đang focus: {e.Message}");
        return;
    }

    var pid = Safe(() => element.CurrentProcessId, -1);
    var process = Safe(() => Process.GetProcessById(pid).ProcessName, "?");
    Console.WriteLine($"\nProcess: {process} (pid {pid})");
    Console.WriteLine($"Loại ô: {Safe(() => element.CurrentLocalizedControlType, "?")} | ControlType {Safe(() => element.CurrentControlType, 0)} | " +
                      $"Class \"{Safe(() => element.CurrentClassName, "")}\" | Framework \"{Safe(() => element.CurrentFrameworkId, "")}\"");

    var isPassword = Safe(() => element.CurrentIsPassword != 0, false);
    var patterns = new List<string>();
    if (Safe(() => element.GetCurrentPattern(UIA_PatternIds.UIA_TextPattern2Id) is not null, false)) patterns.Add("TextPattern2");
    if (Safe(() => element.GetCurrentPattern(UIA_PatternIds.UIA_TextPatternId) is not null, false)) patterns.Add("TextPattern");
    if (Safe(() => element.GetCurrentPattern(UIA_PatternIds.UIA_ValuePatternId) is not null, false)) patterns.Add("ValuePattern");
    Console.WriteLine($"Pattern: {(patterns.Count == 0 ? "(không có)" : string.Join(", ", patterns))} | Ô mật khẩu: {(isPassword ? "có" : "không")}");
    if (isPassword)
    {
        Console.WriteLine("Ô mật khẩu: Grammar không đọc, Probe cũng không in nội dung.");
        return;
    }

    Console.WriteLine("\n-- TextPattern2 (GetCaretRange + đoạn văn) --");
    Show(() => element.GetCurrentPattern(UIA_PatternIds.UIA_TextPattern2Id) is IUIAutomationTextPattern2 t2
        ? ParagraphAround(t2.GetCaretRange(out _))
        : null);

    Console.WriteLine("\n-- TextPattern (đầu vùng chọn + đoạn văn) --");
    Show(() =>
    {
        if (element.GetCurrentPattern(UIA_PatternIds.UIA_TextPatternId) is not IUIAutomationTextPattern t) return null;
        var selection = t.GetSelection();
        return selection is { Length: > 0 } ? ParagraphAround(selection.GetElement(0)) : null;
    });

    Console.WriteLine("\n-- ValuePattern --");
    try
    {
        var value = element.GetCurrentPattern(UIA_PatternIds.UIA_ValuePatternId) is IUIAutomationValuePattern v ? v.CurrentValue : null;
        Console.WriteLine(value is null ? "(không hỗ trợ)" : $"{value.Length} ký tự, cuối: \"{Tail(value)}\"");
    }
    catch (Exception e)
    {
        Console.WriteLine($"Lỗi: {e.GetType().Name}: {e.Message}");
    }

    // Đúng logic của Grammar.
    var probe = new FieldProbe(pid, isPassword,
        CaretParagraph: () => element.GetCurrentPattern(UIA_PatternIds.UIA_TextPattern2Id) is IUIAutomationTextPattern2 t2
            ? ParagraphAround(t2.GetCaretRange(out _)) : null,
        SelectionParagraph: () =>
        {
            if (element.GetCurrentPattern(UIA_PatternIds.UIA_TextPatternId) is not IUIAutomationTextPattern t) return null;
            var s = t.GetSelection();
            return s is { Length: > 0 } ? ParagraphAround(s.GetElement(0)) : null;
        },
        Value: () => element.GetCurrentPattern(UIA_PatternIds.UIA_ValuePatternId) is IUIAutomationValuePattern v ? v.CurrentValue : null);
    var read = FocusedFieldReader.Read(probe, Environment.ProcessId);
    Console.WriteLine("\n== Grammar sẽ kiểm tra ==");
    Console.WriteLine(read is { } r
        ? $"\"{SentenceExtractor.Sentence(r.Text, r.Cursor) ?? "(ô trống)"}\"  (con trỏ: {r.Cursor?.ToString() ?? "không biết, lấy câu cuối"})"
        : "(không đọc được ô này)");
}

static (string Paragraph, string Prefix)? ParagraphAround(IUIAutomationTextRange? caret)
{
    if (caret is null) return null;
    var paragraph = caret.Clone();
    paragraph.ExpandToEnclosingUnit(TextUnit.TextUnit_Paragraph);
    var prefix = paragraph.Clone();
    prefix.MoveEndpointByRange(TextPatternRangeEndpoint.TextPatternRangeEndpoint_End, caret, TextPatternRangeEndpoint.TextPatternRangeEndpoint_Start);
    var text = paragraph.GetText(20_000);
    return text is null ? null : (text, prefix.GetText(20_000) ?? "");
}

static void Show(Func<(string Paragraph, string Prefix)?> read)
{
    try
    {
        if (read() is not { } p)
        {
            Console.WriteLine("(không hỗ trợ hoặc không có con trỏ)");
            return;
        }
        var (text, cursor) = CaretContext.Normalize(p.Paragraph, p.Prefix);
        Console.WriteLine($"Đoạn văn: {text.Length} ký tự, con trỏ ở {cursor}");
        Console.WriteLine($"Quanh con trỏ: \"…{text[Math.Max(0, cursor - 40)..cursor]}|{text[cursor..Math.Min(text.Length, cursor + 40)]}…\"");
        Console.WriteLine($"Câu chứa con trỏ: \"{SentenceExtractor.Sentence(text, cursor)}\"");
    }
    catch (Exception e)
    {
        Console.WriteLine($"Lỗi: {e.GetType().Name}: {e.Message}");
    }
}

static string Tail(string s) => s.Length <= 80 ? s : "…" + s[^80..];

static T Safe<T>(Func<T> f, T fallback)
{
    try
    {
        return f();
    }
    catch (Exception)
    {
        return fallback;
    }
}

static string? ForegroundProcessName()
{
    var hwnd = GetForegroundWindow();
    if (hwnd == IntPtr.Zero) return null;
    GetWindowThreadProcessId(hwnd, out var pid);
    try
    {
        return Process.GetProcessById((int)pid).ProcessName;
    }
    catch (ArgumentException)
    {
        return null;
    }
}

[DllImport("user32.dll")]
static extern IntPtr GetForegroundWindow();

[DllImport("user32.dll")]
static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
