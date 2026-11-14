import CoreGraphics

/// Góc màn hình đặt panel.
public enum PanelCorner: String, CaseIterable, Sendable {
    case topRight, topLeft, bottomRight, bottomLeft

    var isTop: Bool { self == .topRight || self == .topLeft }
    var isLeft: Bool { self == .topLeft || self == .bottomLeft }
}

/// Tính khung panel theo góc đã chọn, trong toạ độ AppKit (gốc ở góc dưới trái).
public enum PanelLayout {
    public static let defaultMargin: CGFloat = 20
    /// Chiều cao dải header luôn nhận chuột (để kéo panel).
    public static let headerHeight: CGFloat = 24

    /// Dải header ở cạnh trên của khung panel (cùng hệ toạ độ với `panelFrame`, gốc dưới trái).
    public static func headerRect(in panelFrame: CGRect) -> CGRect {
        let height = min(headerHeight, panelFrame.height)
        return CGRect(x: panelFrame.minX, y: panelFrame.maxY - height, width: panelFrame.width, height: height)
    }

    /// - Parameters:
    ///   - size: kích thước mong muốn (độ rộng theo cài đặt, chiều cao theo nội dung).
    ///   - visibleFrame: vùng hiển thị của màn hình (đã trừ menu bar và Dock).
    /// - Returns: khung cách mép `margin`. Panel lớn hơn màn hình thì bị kẹp vào trong.
    public static func frame(
        corner: PanelCorner, size: CGSize, visibleFrame: CGRect, margin: CGFloat = defaultMargin
    ) -> CGRect {
        let width = min(size.width, max(0, visibleFrame.width - 2 * margin))
        let height = min(size.height, max(0, visibleFrame.height - 2 * margin))
        let x = corner.isLeft ? visibleFrame.minX + margin : visibleFrame.maxX - margin - width
        let y = corner.isTop ? visibleFrame.maxY - margin - height : visibleFrame.minY + margin
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Khung panel giữ góc trên trái tại `topLeft` (vị trí người dùng đã kéo),
    /// được dời vào trong để nằm trọn `visibleFrame`.
    public static func frame(topLeft: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let x = min(max(topLeft.x, visibleFrame.minX), visibleFrame.maxX - width)
        let top = min(max(topLeft.y, visibleFrame.minY + height), visibleFrame.maxY)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}
