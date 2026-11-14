namespace Grammar.Core.Engine;

/// <summary>Bộ sửa ngữ pháp. Trả về câu đã sửa, hoặc trả nguyên văn nếu câu đã đúng.</summary>
public interface IGrammarEngine
{
    Task<string> CorrectAsync(string sentence, CancellationToken cancellationToken = default);
}

/// <summary>Loại lỗi engine, giống <c>GrammarEngineError</c> của bản Swift.</summary>
public enum GrammarEngineErrorKind
{
    ModelNotFound,
    ModelLoadFailed,
    ContextCreationFailed,
    PromptTemplateFailed,
    TokenizeFailed,
    DecodeFailed,
}

public sealed class GrammarEngineException(GrammarEngineErrorKind kind, string? detail = null, Exception? inner = null)
    : Exception(Describe(kind, detail), inner)
{
    public GrammarEngineErrorKind Kind { get; } = kind;
    public string? Detail { get; } = detail;

    private static string Describe(GrammarEngineErrorKind kind, string? detail) => kind switch
    {
        GrammarEngineErrorKind.ModelNotFound =>
            $"Không tìm thấy model {detail}. Đặt file {detail} vào thư mục Models cạnh Grammar.exe (xem windows/README.md).",
        GrammarEngineErrorKind.ModelLoadFailed =>
            $"Không nạp được model tại {detail}. File có thể bị hỏng, hãy tải lại.",
        GrammarEngineErrorKind.ContextCreationFailed => "Không tạo được ngữ cảnh cho model (có thể thiếu bộ nhớ).",
        GrammarEngineErrorKind.PromptTemplateFailed => "Model không có chat template phù hợp.",
        GrammarEngineErrorKind.TokenizeFailed => "Không tách được token cho câu này.",
        GrammarEngineErrorKind.DecodeFailed => $"Model gặp lỗi khi sinh kết quả (mã {detail}).",
        _ => kind.ToString(),
    };
}
