namespace Grammar.Core.Diff;

/// <summary>
/// Diff Myers bộ nhớ tuyến tính (chia để trị theo "middle snake"), port đúng <c>_linearSpaceMyers</c>
/// mà <c>BidirectionalCollection.difference(from:)</c> của thư viện chuẩn Swift dùng
/// (swiftlang/swift, stdlib/public/core/Diffing.swift).
/// </summary>
/// <remarks>
/// Khi có nhiều cách ghép cặp tối ưu, thứ tự tìm kiếm quyết định từ nào bị đánh dấu là xoá/thêm.
/// Giữ nguyên thuật toán giúp bản Windows gạch chân đúng những từ bản macOS gạch chân.
/// Test <c>MyersParityTests</c> đối chiếu với kết quả của Swift thật (Fixtures/myers-swift.json).
/// </remarks>
internal static class Myers
{
    /// <summary>Kết quả diff: chỉ số phần tử bị xoá trong <c>old</c> và được thêm trong <c>new</c>.</summary>
    internal readonly record struct Changes(HashSet<int> Removed, HashSet<int> Inserted);

    public static Changes Diff(IReadOnlyList<string> old, IReadOnlyList<string> @new)
    {
        var removed = new HashSet<int>();
        var inserted = new HashSet<int>();

        var box = new Rect(0, 0, old.Count, @new.Count).Shrunk(old, @new);
        var myers = new LinearMyers(box.Size, old, @new);
        foreach (var (isInsertion, offset) in myers.FindDifferences(box))
        {
            if (isInsertion) inserted.Add(offset);
            else removed.Add(offset);
        }
        return new Changes(removed, inserted);
    }

    /// <summary>Một vùng chữ nhật của đồ thị chỉnh sửa (Swift: <c>EditGraphRect</c>).</summary>
    private readonly record struct Rect(int Left, int Top, int Right, int Bottom)
    {
        public int Width => Right - Left;
        public int Height => Bottom - Top;
        public int Size => Width + Height;
        public int Delta => Width - Height;
        public bool IsEven => Delta % 2 == 0;
        public bool IsOdd => !IsEven;
        public int Max => (Size + 1) / 2;

        public Rect CroppedToTopLeftOf(Rect limit) => new(Left, Top, limit.Left, limit.Top);

        public Rect CroppedToBottomRightOf(Rect limit) => new(limit.Right, limit.Bottom, Right, Bottom);

        /// <summary>Thu nhỏ từ trên và dưới theo các đường chéo (phần tử bằng nhau).</summary>
        public Rect Shrunk(IReadOnlyList<string> old, IReadOnlyList<string> @new)
        {
            var (left, top, right, bottom) = (Left, Top, Right, Bottom);
            while (left < right && top < bottom && Eq(old[left], @new[top]))
            {
                left++;
                top++;
            }
            while (right > left && bottom > top && Eq(old[right - 1], @new[bottom - 1]))
            {
                right--;
                bottom--;
            }
            return new Rect(left, top, right, bottom);
        }
    }

    private static bool Eq(string a, string b) => string.Equals(a, b, StringComparison.Ordinal);

    /// <summary>Hai k-vector (tiến và lùi), mỗi cái có chỉ số từ <c>-size</c> tới <c>size</c>.</summary>
    private sealed class DoubleKVector(int size)
    {
        private readonly int[] _buffer = new int[(size * 2 + 1) * 2];
        private readonly int _forwardOffset = size;
        private readonly int _backwardOffset = size * 2 + 1 + size;

        public int GetForward(int index) => _buffer[_forwardOffset + index];
        public void SetForward(int index, int value) => _buffer[_forwardOffset + index] = value;
        public int GetBackward(int index) => _buffer[_backwardOffset + index];
        public void SetBackward(int index, int value) => _buffer[_backwardOffset + index] = value;
    }

    private sealed class LinearMyers(int size, IReadOnlyList<string> old, IReadOnlyList<string> @new)
    {
        private readonly DoubleKVector _k = new(size);

        public List<(bool IsInsertion, int Offset)> FindDifferences(Rect initial)
        {
            var result = new List<(bool, int)>();
            var stack = new Stack<Rect>();
            var current = initial;

            while (true)
            {
                var (edit, snakeBox) = MiddleSnake(current);
                if (edit is { } e) result.Add(e);

                if (snakeBox is not { } snake)
                {
                    // Không còn middle snake: xử lý vùng tiếp theo trên stack (phía phải của snake trước).
                    if (stack.Count == 0) return result;
                    current = stack.Pop();
                    continue;
                }

                var headBox = current.CroppedToTopLeftOf(snake).Shrunk(old, @new);
                var tailBox = current.CroppedToBottomRightOf(snake).Shrunk(old, @new);
                current = headBox;
                stack.Push(tailBox);
            }
        }

        private ((bool, int)? Edit, Rect? Snake) MiddleSnake(Rect box)
        {
            if (box.Size <= 1)
            {
                // Một bước sang phải hoặc xuống dưới là một lần xoá hoặc thêm.
                if (box.Size == 0) return (null, null);
                return box.Width == 1 ? ((false, box.Left), null) : ((true, box.Top), null);
            }

            _k.SetForward(1, box.Left);
            _k.SetBackward(1, box.Bottom);

            for (var depth = 0; depth <= box.Max; depth++)
            {
                if (box.IsOdd)
                {
                    if (ForwardSearch(box, depth) is { } r) return (r.Edit, r.Snake);
                    _ = BackwardSearch(box, depth);
                }
                else
                {
                    _ = ForwardSearch(box, depth);
                    if (BackwardSearch(box, depth) is { } r) return (r.Edit, r.Snake);
                }
            }
            throw new InvalidOperationException("Unreachable");
        }

        private ((bool, int) Edit, Rect Snake)? ForwardSearch(Rect box, int depth)
        {
            for (var k = depth; k >= -depth; k -= 2)
            {
                int newRight, newBottom, newLeft, newTop, editIndex;
                bool isInsertion;

                if (k == -depth || (k != depth && _k.GetForward(k - 1) < _k.GetForward(k + 1)))
                {
                    newRight = _k.GetForward(k + 1);
                    newLeft = newRight;
                    newBottom = box.Top + (newRight - box.Left) - k;
                    isInsertion = true;
                    editIndex = newBottom - 1;
                }
                else
                {
                    newLeft = _k.GetForward(k - 1);
                    newRight = newLeft + 1;
                    newBottom = box.Top + (newRight - box.Left) - k;
                    isInsertion = false;
                    editIndex = newLeft;
                }
                newTop = depth == 0 || newRight != newLeft ? newBottom : newBottom - 1;

                while (newRight < box.Right && newBottom < box.Bottom && Eq(old[newRight], @new[newBottom]))
                {
                    newRight++;
                    newBottom++;
                }
                _k.SetForward(k, newRight);

                // Chỉ kiểm tra chồng lấn khi đi tiến trong vùng có kích thước lẻ.
                if (!box.IsOdd) continue;

                var c = k - box.Delta;
                if (c >= -(depth - 1) && c <= depth - 1 && newBottom >= _k.GetBackward(c))
                    return ((isInsertion, editIndex), new Rect(newLeft, newTop, newRight, newBottom));
            }
            return null;
        }

        private ((bool, int) Edit, Rect Snake)? BackwardSearch(Rect box, int depth)
        {
            for (var c = depth; c >= -depth; c -= 2)
            {
                var k = c + box.Delta;
                int newLeft, newTop, newRight, newBottom, editIndex;
                bool isInsertion;

                if (c == -depth || (c != depth && _k.GetBackward(c - 1) > _k.GetBackward(c + 1)))
                {
                    newTop = _k.GetBackward(c + 1);
                    newBottom = newTop;
                    newLeft = box.Left + (newTop - box.Top) + k;
                    isInsertion = false;
                    editIndex = newLeft;
                }
                else
                {
                    newBottom = _k.GetBackward(c - 1);
                    newTop = newBottom - 1;
                    newLeft = box.Left + (newTop - box.Top) + k;
                    isInsertion = true;
                    editIndex = newTop;
                }
                newRight = depth == 0 || newTop != newBottom ? newLeft : newLeft + 1;

                while (newLeft > box.Left && newTop > box.Top && Eq(old[newLeft - 1], @new[newTop - 1]))
                {
                    newLeft--;
                    newTop--;
                }
                _k.SetBackward(c, newTop);

                // Chỉ kiểm tra chồng lấn khi đi lùi trong vùng có kích thước chẵn.
                if (!box.IsEven) continue;

                if (k >= -depth && k <= depth && newLeft <= _k.GetForward(k))
                    return ((isInsertion, editIndex), new Rect(newLeft, newTop, newRight, newBottom));
            }
            return null;
        }
    }
}
