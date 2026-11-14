using Grammar.Core.Text;

namespace Grammar.Core.Diff;

/// <summary>Kết luận của <see cref="EditGuard"/>.</summary>
public enum EditVerdict
{
    Unchanged,
    Accepted,
    Rewritten,
}

/// <summary>
/// Chặn những kết quả mà mô hình "viết lại câu" thay vì chỉ sửa ngữ pháp.
/// Port của GrammarKit/Diff/EditGuard.swift.
/// </summary>
public sealed record EditGuard(double MaxChangeRatio = 0.4, double MaxTotalChangeRatio = 0.8)
{
    // MaxChangeRatio: tỉ lệ token gốc bị thay bằng từ khác hẳn tối đa được chấp nhận.
    //   Sửa dạng từ/chính tả (collect → collecting) không tính.
    // MaxTotalChangeRatio: tỉ lệ tổng số token thay đổi tối đa (kể cả sửa dạng từ),
    //   chặn trường hợp gần như cả câu bị đổi.

    public EditVerdict Evaluate(WordDiff diff)
    {
        if (diff.IsIdentical) return EditVerdict.Unchanged;
        if (diff.DissimilarChangeRatio > MaxChangeRatio) return EditVerdict.Rewritten;
        if (diff.ChangeRatio > MaxTotalChangeRatio) return EditVerdict.Rewritten;
        // Mô hình tách thành nhiều câu hơn câu gốc -> đang diễn đạt lại.
        if (SentenceSegmenter.Count(diff.Corrected) > Math.Max(1, SentenceSegmenter.Count(diff.Original)))
            return EditVerdict.Rewritten;
        return EditVerdict.Accepted;
    }
}
