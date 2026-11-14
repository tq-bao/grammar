using Grammar.Core.Capture;
using Grammar.Core.Pipeline;

namespace Grammar.Core.Tests;

/// <summary>Spec text-capture: chọn cách đọc ô và loại trừ nội dung nhạy cảm.</summary>
public class FocusedFieldReaderTests
{
    private const int Own = 100;
    private const int Other = 200;

    [Fact]
    public void CaretParagraphIsPreferred()
    {
        var probe = new FieldProbe(Other, false,
            CaretParagraph: () => ("I like tea. He have two cats.", "I like tea. He ha"),
            SelectionParagraph: () => throw new InvalidOperationException("không được gọi"),
            Value: () => "toàn bộ nội dung");
        var read = FocusedFieldReader.Read(probe, Own);
        Assert.Equal(new FieldText("I like tea. He have two cats.", 17), read);
        Assert.Equal("He have two cats.", SentenceExtractor.Sentence(read!.Value.Text, read.Value.Cursor));
    }

    [Fact]
    public void FallsBackToSelectionThenValue()
    {
        var selection = new FieldProbe(Other, false,
            CaretParagraph: () => null,
            SelectionParagraph: () => ("She go home.", "She go"));
        Assert.Equal(new FieldText("She go home.", 6), FocusedFieldReader.Read(selection, Own));

        var valueOnly = new FieldProbe(Other, false, Value: () => "I like tea. We is fine.");
        var read = FocusedFieldReader.Read(valueOnly, Own);
        Assert.Equal(new FieldText("I like tea. We is fine.", null), read);
        // Spec: "Không có thông tin con trỏ" -> câu cuối.
        Assert.Equal("We is fine.", SentenceExtractor.Sentence(read!.Value.Text, read.Value.Cursor));
    }

    [Fact]
    public void PasswordFieldIsNeverRead()
    {
        // Spec: "Ô mật khẩu".
        var probe = new FieldProbe(Other, true, Value: () => throw new InvalidOperationException("không được đọc ô mật khẩu"));
        Assert.Null(FocusedFieldReader.Read(probe, Own));
    }

    [Fact]
    public void OwnProcessIsNeverRead()
    {
        // Spec: "Cửa sổ của chính app" (cửa sổ Cài đặt đang focus).
        var probe = new FieldProbe(Own, false, Value: () => "Cài đặt");
        Assert.Null(FocusedFieldReader.Read(probe, Own));
    }

    [Fact]
    public void AccessDeniedFromElevatedAppIsSkippedSilently()
    {
        // Spec: "App chạy quyền quản trị trên Windows" - mọi lời gọi đều lỗi (UIPI).
        var denied = new UnauthorizedAccessException("E_ACCESSDENIED");
        var probe = new FieldProbe(Other, false,
            CaretParagraph: () => throw denied,
            SelectionParagraph: () => throw denied,
            Value: () => throw denied);
        Assert.Null(FocusedFieldReader.Read(probe, Own));
    }

    [Fact]
    public void BrokenBranchFallsThroughToNext()
    {
        var probe = new FieldProbe(Other, false,
            CaretParagraph: () => throw new TimeoutException(),
            Value: () => "They was happy.");
        Assert.Equal(new FieldText("They was happy.", null), FocusedFieldReader.Read(probe, Own));
    }

    [Fact]
    public void EmbeddedObjectsAreRemovedKeepingCaretAligned()
    {
        var probe = new FieldProbe(Other, false,
            CaretParagraph: () => ("Ping \uFFFC about it. She go home now.", "Ping \uFFFC about it. She go"));
        var read = FocusedFieldReader.Read(probe, Own)!.Value;
        Assert.Equal("She go home now.", SentenceExtractor.Sentence(read.Text, read.Cursor));
    }

    [Fact]
    public void NoPatternMeansNothingToRead() =>
        Assert.Null(FocusedFieldReader.Read(new FieldProbe(Other, false), Own));
}

public class ChangeFilterTests
{
    [Fact]
    public void EmitsOnlyRealChanges()
    {
        var filter = new ChangeFilter();
        Assert.True(filter.ShouldEmit(new FieldText("a", 1)));
        Assert.False(filter.ShouldEmit(new FieldText("a", 1)));
        Assert.True(filter.ShouldEmit(new FieldText("a", 0)));    // con trỏ đổi
        Assert.True(filter.ShouldEmit(new FieldText("ab", 0)));   // nội dung đổi
        filter.Reset();
        Assert.True(filter.ShouldEmit(new FieldText("ab", 0)));
    }
}
