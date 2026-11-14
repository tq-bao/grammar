using Grammar.Core.Diff;

namespace Grammar.Core.Pipeline;

/// <summary>Trạng thái hiển thị trên panel. Port của enum <c>CheckState</c> (CheckCoordinator.swift).</summary>
public abstract record CheckState
{
    private CheckState() { }

    /// <summary>Chưa có câu nào, hoặc câu quá ngắn nên không kiểm tra.</summary>
    public sealed record Idle : CheckState;

    /// <summary>Đang nạp model, chưa kiểm tra được.</summary>
    public sealed record LoadingModel : CheckState;

    public sealed record Checking(string Sentence) : CheckState;

    public sealed record Ok(string Sentence) : CheckState;

    public sealed record Corrected(WordDiff Diff) : CheckState;

    public sealed record NotEnglish(string Sentence) : CheckState;

    /// <summary>Mô hình viết lại câu (EditGuard từ chối) nên không hiển thị kết quả.</summary>
    public sealed record Uncertain(string Sentence) : CheckState;

    public sealed record ModelError(string Message) : CheckState;

    public static readonly CheckState IdleState = new Idle();
    public static readonly CheckState LoadingModelState = new LoadingModel();
}

/// <summary>Nguồn của câu đang kiểm tra. Bản Windows không có phím tắt kiểm tra đoạn bôi đen.</summary>
public enum TextSource
{
    FocusedField,
    Manual,
}
