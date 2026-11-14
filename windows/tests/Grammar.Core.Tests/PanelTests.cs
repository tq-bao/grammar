using Grammar.Core.Panel;

namespace Grammar.Core.Tests;

// Port của GrammarAppTests/PanelTests.swift. Bản Swift dùng toạ độ AppKit (gốc dưới trái);
// ở đây đảo trục y sang toạ độ Windows (gốc trên trái), giữ nguyên quy tắc.
public class PanelLayoutTests
{
    // Vùng làm việc không bắt đầu ở (0,0): taskbar 48 DIP ở dưới, màn hình 1440x900 bắt đầu ở y = 0.
    private static readonly Rect Work = new(0, 0, 1440, 852);
    private static readonly Size PanelSize = new(460, 200);

    [Fact]
    public void TopRight() =>
        Assert.Equal(new Rect(1440 - 20 - 460, 20, 460, 200), PanelLayout.Frame(PanelCorner.TopRight, PanelSize, Work));

    [Fact]
    public void TopLeft()
    {
        var f = PanelLayout.Frame(PanelCorner.TopLeft, PanelSize, Work);
        Assert.Equal(20, f.Left);
        Assert.Equal(Work.Top + 20, f.Top);
    }

    [Fact]
    public void BottomRight()
    {
        // Spec checker-window, scenario "Góc dưới phải" và "Taskbar ở cạnh dưới trên Windows".
        var f = PanelLayout.Frame(PanelCorner.BottomRight, PanelSize, Work);
        Assert.Equal(Work.Right - 20, f.Right);
        Assert.Equal(Work.Bottom - 20, f.Bottom);
    }

    [Fact]
    public void BottomLeft()
    {
        var f = PanelLayout.Frame(PanelCorner.BottomLeft, PanelSize, Work);
        Assert.Equal((20.0, 852.0 - 20 - 200), (f.X, f.Y));
    }

    [Fact]
    public void TaskbarOnTopOrLeft()
    {
        // Taskbar ở cạnh trên: vùng làm việc bắt đầu ở y = 48.
        var top = new Rect(0, 48, 1440, 852);
        Assert.Equal(68, PanelLayout.Frame(PanelCorner.TopRight, PanelSize, top).Top);
        // Taskbar ở cạnh trái: vùng làm việc bắt đầu ở x = 64.
        var left = new Rect(64, 0, 1376, 900);
        Assert.Equal(84, PanelLayout.Frame(PanelCorner.BottomLeft, PanelSize, left).Left);
    }

    [Fact]
    public void SecondaryScreenOffset()
    {
        var screen = new Rect(-1920, 0, 1920, 1080);
        Assert.Equal(-1900, PanelLayout.Frame(PanelCorner.TopLeft, PanelSize, screen).Left);
    }

    [Fact]
    public void LargerThanScreenIsClamped()
    {
        var small = new Rect(0, 0, 400, 300);
        var f = PanelLayout.Frame(PanelCorner.BottomRight, new Size(700, 900), small);
        Assert.Equal(new Rect(20, 20, 360, 260), f);
        Assert.True(small.Contains(f));
    }
}

public class PanelLayoutTopLeftTests
{
    private static readonly Rect Work = new(0, 0, 1440, 852);
    private static readonly Size PanelSize = new(460, 200);

    [Fact]
    public void KeepsTopLeftWhenItFits() =>
        Assert.Equal(new Rect(500, 300, 460, 200), PanelLayout.Frame(new Point(500, 300), PanelSize, Work));

    [Fact]
    public void NearBottomEdgeIsPushedUp()
    {
        // Spec checker-window, scenario "Nội dung dài ra".
        var f = PanelLayout.Frame(new Point(500, 800), PanelSize, Work);
        Assert.Equal(Work.Bottom, f.Bottom);
        Assert.Equal(200, f.Height);
    }

    [Fact]
    public void OutsideScreenIsClampedInside()
    {
        var f = PanelLayout.Frame(new Point(5000, 5000), PanelSize, Work);
        Assert.True(Work.Contains(f));
        Assert.Equal(Work.Right, f.Right);
        Assert.Equal(Work.Bottom, f.Bottom);
    }

    [Fact]
    public void AboveScreenIsClampedDown() =>
        Assert.Equal(0, PanelLayout.Frame(new Point(10, -300), PanelSize, Work).Top);
}

public class PanelHeaderTests
{
    private static readonly Rect PanelFrame = new(100, 200, 460, 180);  // Top = 200

    [Fact]
    public void HeaderIsTopStrip() =>
        Assert.Equal(new Rect(100, 200, 460, 24), PanelLayout.HeaderRect(PanelFrame));

    [Fact]
    public void PointsInsideAndOutsideHeader()
    {
        var header = PanelLayout.HeaderRect(PanelFrame);
        Assert.True(header.Contains(new Point(300, 210)));   // trong header
        Assert.True(header.Contains(new Point(101, 200)));   // mép trên header
        Assert.False(header.Contains(new Point(300, 224)));  // ngay dưới header: phần nội dung
        Assert.False(header.Contains(new Point(300, 199)));  // phía trên khung
        Assert.False(header.Contains(new Point(99, 210)));   // bên trái panel
    }

    [Fact]
    public void VeryShortPanel()
    {
        var tiny = new Rect(0, 0, 100, 10);
        Assert.Equal(tiny, PanelLayout.HeaderRect(tiny));
    }
}

public class PanelSettingsTests
{
    [Fact]
    public void DefaultsWhenEmpty()
    {
        var s = new PanelSettings(new MemorySettingsStore());
        Assert.Equal(0.75, s.BackgroundOpacity);
        Assert.Equal(PanelCorner.TopRight, s.Corner);
        Assert.Equal(460, s.Width);
        Assert.True(s.ClickThrough);
        Assert.Null(s.CustomTopLeft);
        Assert.Null(s.Model);
    }

    [Fact]
    public void ValuesPersistAcrossInstances()
    {
        // Spec checker-window, scenario "Khởi động lại app".
        var store = new MemorySettingsStore();
        _ = new PanelSettings(store)
        {
            BackgroundOpacity = 0.3,
            Corner = PanelCorner.BottomLeft,
            Width = 520,
            Model = "Qwen2.5-3B-Instruct-Q4_K_M.gguf",
        };

        var reloaded = new PanelSettings(store);
        Assert.Equal(0.3, reloaded.BackgroundOpacity);
        Assert.Equal(PanelCorner.BottomLeft, reloaded.Corner);
        Assert.Equal(520, reloaded.Width);
        Assert.Equal("Qwen2.5-3B-Instruct-Q4_K_M.gguf", reloaded.Model);
    }

    [Fact]
    public void OutOfRangeValuesAreClamped()
    {
        var store = new MemorySettingsStore("""{ "backgroundOpacity": 5.0, "width": 10.0, "corner": "middle" }""");
        var s = new PanelSettings(store);
        Assert.Equal(1.0, s.BackgroundOpacity);
        Assert.Equal(320, s.Width);
        Assert.Equal(PanelCorner.TopRight, s.Corner);

        s.BackgroundOpacity = -1;
        Assert.Equal(0, s.BackgroundOpacity);
        s.Width = 9999;
        Assert.Equal(700, s.Width);
        Assert.Equal(700, new PanelSettings(store).Width);
    }

    [Theory]
    [InlineData("not json at all")]
    [InlineData("[1, 2, 3]")]
    [InlineData("""{ "backgroundOpacity": "high", "width": null, "clickThrough": "yes", "customTopLeft": "x" }""")]
    [InlineData("")]
    public void BrokenOrWrongTypedFileFallsBackToDefaults(string json)
    {
        var s = new PanelSettings(new MemorySettingsStore(json));
        Assert.Equal(0.75, s.BackgroundOpacity);
        Assert.Equal(460, s.Width);
        Assert.True(s.ClickThrough);
        Assert.Null(s.CustomTopLeft);
    }

    [Fact]
    public void MissingFieldsUseDefaultsAndOthersAreKept()
    {
        var s = new PanelSettings(new MemorySettingsStore("""{ "corner": "bottomRight" }"""));
        Assert.Equal(PanelCorner.BottomRight, s.Corner);
        Assert.Equal(0.75, s.BackgroundOpacity);
    }

    [Fact]
    public void ResetToDefaults()
    {
        var store = new MemorySettingsStore();
        var s = new PanelSettings(store) { BackgroundOpacity = 0.1, Corner = PanelCorner.BottomRight, Width = 600 };
        s.ResetToDefaults();
        Assert.Equal(0.75, s.BackgroundOpacity);
        Assert.Equal(PanelCorner.TopRight, s.Corner);
        Assert.Equal(460, s.Width);
        Assert.Equal(PanelCorner.TopRight, new PanelSettings(store).Corner);
    }

    [Fact]
    public void ClickThroughAndPositionPersist()
    {
        // Spec checker-window, scenario "Giữ vị trí sau khi khởi động lại".
        var store = new MemorySettingsStore();
        _ = new PanelSettings(store) { ClickThrough = false, CustomTopLeft = new Point(300, 700) };
        var reloaded = new PanelSettings(store);
        Assert.False(reloaded.ClickThrough);
        Assert.Equal(new Point(300, 700), reloaded.CustomTopLeft);
    }

    [Fact]
    public void ChoosingCornerClearsDraggedPosition()
    {
        var store = new MemorySettingsStore();
        var s = new PanelSettings(store) { CustomTopLeft = new Point(300, 700) };
        s.Corner = PanelCorner.BottomLeft;
        Assert.Null(s.CustomTopLeft);
        Assert.Null(new PanelSettings(store).CustomTopLeft);
    }

    [Fact]
    public void ChoosingSameCornerAlsoClearsDraggedPosition()
    {
        // Bản Swift gán lại cùng góc cũng bỏ vị trí đã kéo (didSet luôn chạy).
        var s = new PanelSettings(new MemorySettingsStore()) { CustomTopLeft = new Point(1, 2) };
        s.Corner = s.Corner;
        Assert.Null(s.CustomTopLeft);
    }

    [Fact]
    public void ResetPositionAndResetToDefaults()
    {
        var s = new PanelSettings(new MemorySettingsStore()) { CustomTopLeft = new Point(1, 2) };
        s.ResetPosition();
        Assert.Null(s.CustomTopLeft);

        s.ClickThrough = false;
        s.CustomTopLeft = new Point(1, 2);
        s.ResetToDefaults();
        Assert.True(s.ClickThrough);
        Assert.Null(s.CustomTopLeft);
    }

    [Theory]
    [InlineData("""{ "customTopLeft": ["a", "b"] }""")]
    [InlineData("""{ "customTopLeft": [1.0] }""")]
    public void InvalidStoredPositionIsIgnored(string json) =>
        Assert.Null(new PanelSettings(new MemorySettingsStore(json)).CustomTopLeft);

    [Fact]
    public void NonFinitePositionIsRejected()
    {
        var s = new PanelSettings(new MemorySettingsStore()) { CustomTopLeft = new Point(double.NaN, 1) };
        Assert.Null(s.CustomTopLeft);
    }

    [Fact]
    public void FileStoreRoundTrip()
    {
        var dir = Path.Combine(Path.GetTempPath(), "grammar-settings-" + Guid.NewGuid().ToString("N"));
        try
        {
            var store = new FileSettingsStore(Path.Combine(dir, "settings.json"));
            Assert.Null(store.Load());
            _ = new PanelSettings(store) { Width = 500 };
            Assert.Equal(500, new PanelSettings(new FileSettingsStore(Path.Combine(dir, "settings.json"))).Width);
        }
        finally
        {
            if (Directory.Exists(dir)) Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public void RaisesPropertyChanged()
    {
        var s = new PanelSettings(new MemorySettingsStore());
        var changed = new List<string?>();
        s.PropertyChanged += (_, e) => changed.Add(e.PropertyName);
        s.BackgroundOpacity = 0.5;
        s.Corner = PanelCorner.BottomLeft;
        Assert.Contains(nameof(PanelSettings.BackgroundOpacity), changed);
        Assert.Contains(nameof(PanelSettings.Corner), changed);
    }
}
