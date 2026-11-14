using Grammar.Core.Diff;
using Grammar.Core.Pipeline;

namespace Grammar.Core.Panel;

/// <summary>Sắc thái của nhãn trạng thái.</summary>
public enum StatusTone
{
    Neutral,
    Good,
    Bad,
    Warning,
}

/// <summary>Biểu tượng của nhãn trạng thái (UI chọn ký hiệu phù hợp).</summary>
public enum StatusIcon
{
    Paused,
    Waiting,
    Busy,
    Ok,
    Error,
    Language,
    Question,
    Failure,
}

/// <summary>Toàn bộ nội dung chữ của panel ở một thời điểm.</summary>
/// <param name="Original">Phần trên: câu đang gõ.</param>
/// <param name="Corrected">Phần dưới: câu đã sửa, hoặc dòng thông báo.</param>
/// <param name="OriginalIsPlaceholder">Phần trên là chữ gợi ý (vẽ mờ).</param>
/// <param name="CorrectedIsPlaceholder">Phần dưới là chữ gợi ý (vẽ mờ).</param>
/// <param name="CorrectedIsError">Phần dưới là thông báo lỗi (vẽ đỏ).</param>
public sealed record PanelContent(
    IReadOnlyList<StyledSegment> Original,
    bool OriginalIsPlaceholder,
    IReadOnlyList<StyledSegment> Corrected,
    bool CorrectedIsPlaceholder,
    bool CorrectedIsError,
    string Status,
    StatusTone Tone,
    StatusIcon Icon);

/// <summary>
/// Chuyển trạng thái kiểm tra thành nội dung panel. Port phần tính chữ của TwoPaneView.swift
/// (originalContent, correctedContent, StatusBadge), tách khỏi WPF để test được.
/// </summary>
public static class PanelPresenter
{
    public const string EmptyHint = "Gõ một câu tiếng Anh ở bất kỳ app nào.";

    public static PanelContent Present(CheckState state, string sentence, bool isPaused)
    {
        var (original, originalPlaceholder) = state is CheckState.Corrected c
            ? (DiffHighlighter.OriginalSegments(c.Diff), false)
            : sentence.Length == 0
                ? (DiffHighlighter.Plain(EmptyHint), true)
                : (DiffHighlighter.Plain(sentence), false);

        var (corrected, correctedPlaceholder, isError) = state switch
        {
            CheckState.Corrected x => (DiffHighlighter.CorrectedSegments(x.Diff), false, false),
            CheckState.Ok x => (DiffHighlighter.Plain(x.Sentence), false, false),
            CheckState.Checking => (DiffHighlighter.Plain("Đang kiểm tra…"), true, false),
            CheckState.NotEnglish => (DiffHighlighter.Plain("Câu này không phải tiếng Anh nên không kiểm tra."), true, false),
            CheckState.Uncertain => (DiffHighlighter.Plain("Không chắc chắn: model muốn viết lại cả câu nên kết quả bị bỏ qua."), true, false),
            CheckState.ModelError x => (DiffHighlighter.Plain(x.Message), false, true),
            CheckState.LoadingModel => (DiffHighlighter.Plain("Đang nạp model…"), true, false),
            _ => (DiffHighlighter.Plain("—"), true, false),
        };

        var (status, tone, icon) = Status(state, isPaused);
        return new PanelContent(original, originalPlaceholder, corrected, correctedPlaceholder, isError, status, tone, icon);
    }

    /// <summary>Nhãn trạng thái ở góc panel (spec checker-window: "Trạng thái kiểm tra").</summary>
    public static (string Text, StatusTone Tone, StatusIcon Icon) Status(CheckState state, bool isPaused)
    {
        if (isPaused) return ("Đã tạm dừng", StatusTone.Neutral, StatusIcon.Paused);
        return state switch
        {
            CheckState.Idle => ("Đang chờ", StatusTone.Neutral, StatusIcon.Waiting),
            CheckState.LoadingModel => ("Đang nạp model", StatusTone.Neutral, StatusIcon.Busy),
            CheckState.Checking => ("Đang kiểm tra", StatusTone.Neutral, StatusIcon.Busy),
            CheckState.Ok => ("Không có lỗi ngữ pháp", StatusTone.Good, StatusIcon.Ok),
            CheckState.Corrected c => ($"Có lỗi ({Math.Max(ErrorCount(c.Diff), 1)})", StatusTone.Bad, StatusIcon.Error),
            CheckState.NotEnglish => ("Không phải tiếng Anh", StatusTone.Neutral, StatusIcon.Language),
            CheckState.Uncertain => ("Không chắc chắn", StatusTone.Warning, StatusIcon.Question),
            CheckState.ModelError => ("Lỗi model", StatusTone.Bad, StatusIcon.Failure),
            _ => ("Đang chờ", StatusTone.Neutral, StatusIcon.Waiting),
        };
    }

    private static int ErrorCount(WordDiff diff) =>
        DiffHighlighter.Highlights(diff).Underlines.Count + diff.MissingPositions.Count;
}
