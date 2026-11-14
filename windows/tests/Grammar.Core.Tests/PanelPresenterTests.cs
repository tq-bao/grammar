using Grammar.Core.Diff;
using Grammar.Core.Panel;
using Grammar.Core.Pipeline;

namespace Grammar.Core.Tests;

/// <summary>Spec checker-window: "Panel hai phần", "Gạch chân đỏ cụm sai", "Làm nổi bật phần đã sửa", "Trạng thái kiểm tra".</summary>
public class PanelPresenterTests
{
    private static string Text(IReadOnlyList<StyledSegment> s) => string.Concat(s.Select(x => x.Text));

    [Fact]
    public void CorrectedShowsBothSentencesWithHighlights()
    {
        // Scenario "Có lỗi ngữ pháp" và "Thay một từ".
        var diff = new WordDiff("He have two cats.", "He has two cats.");
        var c = PanelPresenter.Present(new CheckState.Corrected(diff), "He have two cats.", false);
        Assert.Equal("He have two cats.", Text(c.Original));
        Assert.Equal(["have"], c.Original.Where(s => s.Style == SegmentStyle.Error).Select(s => s.Text));
        Assert.Equal("He has two cats.", Text(c.Corrected));
        Assert.Equal(["has"], c.Corrected.Where(s => s.Style == SegmentStyle.Fix).Select(s => s.Text));
        Assert.Equal("Có lỗi (1)", c.Status);
        Assert.Equal(StatusTone.Bad, c.Tone);
    }

    [Fact]
    public void MissingWordCountsAsError()
    {
        var diff = new WordDiff("I going home.", "I am going home.");
        var c = PanelPresenter.Present(new CheckState.Corrected(diff), "I going home.", false);
        Assert.Equal([" "], c.Original.Where(s => s.Style == SegmentStyle.Gap).Select(s => s.Text));
        Assert.Equal("Có lỗi (1)", c.Status);
    }

    [Fact]
    public void CorrectSentenceHasNoUnderline()
    {
        // Scenario "Câu đúng".
        var c = PanelPresenter.Present(new CheckState.Ok("I have finished the report."), "I have finished the report.", false);
        Assert.All(c.Original, s => Assert.Equal(SegmentStyle.Plain, s.Style));
        Assert.Equal("Không có lỗi ngữ pháp", c.Status);
        Assert.Equal(StatusTone.Good, c.Tone);
    }

    [Theory]
    [InlineData("checking", "Đang kiểm tra", "Đang kiểm tra…")]
    [InlineData("notEnglish", "Không phải tiếng Anh", "Câu này không phải tiếng Anh nên không kiểm tra.")]
    [InlineData("uncertain", "Không chắc chắn", "Không chắc chắn: model muốn viết lại cả câu nên kết quả bị bỏ qua.")]
    [InlineData("loading", "Đang nạp model", "Đang nạp model…")]
    [InlineData("idle", "Đang chờ", "—")]
    public void StatusesMatchMacOS(string kind, string status, string lower)
    {
        CheckState state = kind switch
        {
            "checking" => new CheckState.Checking("x y z"),
            "notEnglish" => new CheckState.NotEnglish("x y z"),
            "uncertain" => new CheckState.Uncertain("x y z"),
            "loading" => CheckState.LoadingModelState,
            _ => CheckState.IdleState,
        };
        var c = PanelPresenter.Present(state, "x y z", false);
        Assert.Equal(status, c.Status);
        Assert.Equal(lower, Text(c.Corrected));
        Assert.True(c.CorrectedIsPlaceholder);
    }

    [Fact]
    public void ModelErrorIsShownInRed()
    {
        // Spec grammar-correction: "Model chưa sẵn sàng" / "Thiếu thư mục model trên Windows".
        var c = PanelPresenter.Present(new CheckState.ModelError("Không tìm thấy model X.gguf"), "", false);
        Assert.Equal("Lỗi model", c.Status);
        Assert.True(c.CorrectedIsError);
        Assert.Equal("Không tìm thấy model X.gguf", Text(c.Corrected));
    }

    [Fact]
    public void EmptySentenceShowsHintWithoutHotkey()
    {
        var c = PanelPresenter.Present(CheckState.IdleState, "", false);
        Assert.True(c.OriginalIsPlaceholder);
        Assert.Equal(PanelPresenter.EmptyHint, Text(c.Original));
        Assert.DoesNotContain("⌃⌥", Text(c.Original));
    }

    [Fact]
    public void PausedOverridesStatus() =>
        Assert.Equal("Đã tạm dừng", PanelPresenter.Present(CheckState.IdleState, "", true).Status);
}

/// <summary>Spec checker-window (Windows): "Kích thước theo DPI trên Windows", "Vị trí panel theo góc màn hình".</summary>
public class PanelPlacementTests
{
    [Fact]
    public void Scale150MakesPanel690PixelsWide()
    {
        // Scenario "Màn hình scale 150%": độ rộng 460 -> 690 pixel vật lý.
        var work = new Rect(0, 0, 2880, 1728);
        var f = PanelPlacement.Compute(PanelCorner.TopRight, null, new Size(460, 200), work, 1.5);
        Assert.Equal(690, f.Width);
        Assert.Equal(300, f.Height);
        Assert.Equal(work.Right - 30, f.Right);  // cách mép 20 DIP = 30 pixel
        Assert.Equal(30, f.Top);
    }

    [Fact]
    public void BottomRightAboveTaskbar()
    {
        // Scenario "Taskbar ở cạnh dưới trên Windows": vùng làm việc đã trừ taskbar 48 px.
        var work = new Rect(0, 0, 1920, 1032);
        var f = PanelPlacement.Compute(PanelCorner.BottomRight, null, new Size(460, 200), work, 1.0);
        Assert.Equal(1032 - 20, f.Bottom);
        Assert.Equal(1920 - 20, f.Right);
    }

    [Fact]
    public void DraggedPositionOnSecondMonitorIsKeptInside()
    {
        // Màn hình thứ hai ở bên phải, scale 150%.
        var work = new Rect(1920, 0, 2880, 1680);
        var f = PanelPlacement.Compute(PanelCorner.TopRight, new Point(4700, 100), new Size(460, 200), work, 1.5);
        Assert.Equal(work.Right, f.Right);   // bị đẩy vào trong
        Assert.Equal(100, f.Top);
    }

    [Fact]
    public void HeaderScalesWithDpi() =>
        Assert.Equal(new Rect(10, 20, 690, 36), PanelPlacement.HeaderRect(new Rect(10, 20, 690, 300), 1.5));
}
