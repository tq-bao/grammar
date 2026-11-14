using Grammar.Core.Pipeline;

namespace Grammar.Core.Capture;

/// <summary>
/// Những gì đọc được từ ô đang focus. Mỗi cách đọc là một hàm, chỉ được gọi khi cần (gọi UI Automation tốn thời gian),
/// và có thể ném lỗi (app không phản hồi, app chạy quyền admin, phần tử đã biến mất...).
/// </summary>
/// <param name="ProcessId">Process sở hữu ô.</param>
/// <param name="IsPassword">Ô mật khẩu: không bao giờ đọc nội dung.</param>
/// <param name="CaretParagraph">
/// TextPattern2: đoạn văn chứa con trỏ và phần từ đầu đoạn tới con trỏ. <c>null</c> nếu ô không hỗ trợ.
/// Tương đương nhánh text marker của bản macOS (Chrome, Edge, Electron, WebView2).
/// </param>
/// <param name="SelectionParagraph">TextPattern (không có TextPattern2): đoạn văn chứa đầu vùng chọn và phần trước nó.</param>
/// <param name="Value">ValuePattern: toàn bộ nội dung ô, không có vị trí con trỏ.</param>
public sealed record FieldProbe(
    int ProcessId,
    bool IsPassword,
    Func<(string Paragraph, string Prefix)?>? CaretParagraph = null,
    Func<(string Paragraph, string Prefix)?>? SelectionParagraph = null,
    Func<string?>? Value = null);

/// <summary>Nội dung đưa vào pipeline: đoạn text và vị trí con trỏ (UTF-16), <c>null</c> nếu không biết.</summary>
public readonly record struct FieldText(string Text, int? Cursor);

/// <summary>
/// Chọn cách đọc ô đang focus và lọc theo spec text-capture ("Loại trừ nội dung nhạy cảm",
/// "App chạy quyền quản trị trên Windows"). Không phụ thuộc UI Automation nên test được trên mọi nền tảng.
/// </summary>
public static class FocusedFieldReader
{
    /// <returns><c>null</c> khi không được đọc (ô mật khẩu, chính app) hoặc không đọc được (không pattern nào dùng được).</returns>
    public static FieldText? Read(FieldProbe probe, int ownProcessId)
    {
        if (probe.ProcessId == ownProcessId) return null;
        if (probe.IsPassword) return null;

        foreach (var paragraph in new[] { probe.CaretParagraph, probe.SelectionParagraph })
        {
            if (Try(paragraph) is { } p)
            {
                var (text, cursor) = CaretContext.Normalize(p.Paragraph, p.Prefix);
                return new FieldText(text, cursor);
            }
        }

        // Chỉ có giá trị: không biết con trỏ, SentenceExtractor sẽ lấy câu cuối.
        return Try(probe.Value) is { } value ? new FieldText(value, null) : null;
    }

    /// <summary>Gọi một cách đọc; lỗi (ví dụ COMException khi app chạy quyền admin) coi như cách đó không dùng được.</summary>
    private static T? Try<T>(Func<T?>? read)
    {
        if (read is null) return default;
        try
        {
            return read();
        }
        catch (Exception)
        {
            return default;
        }
    }
}

/// <summary>Chỉ báo thay đổi khi nội dung hoặc vị trí con trỏ thực sự khác lần trước (giống <c>lastEmitted</c> của bản macOS).</summary>
public sealed class ChangeFilter
{
    private FieldText? _last;

    public bool ShouldEmit(FieldText value)
    {
        if (_last == value) return false;
        _last = value;
        return true;
    }

    /// <summary>Quên giá trị cũ (khi tạm dừng hoặc chuyển ô), để lần đọc sau luôn được báo.</summary>
    public void Reset() => _last = null;
}
