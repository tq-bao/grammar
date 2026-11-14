import CoreGraphics
import Foundation
import Observation

/// Cài đặt hiển thị của panel, lưu trong `UserDefaults`.
/// Mỗi thay đổi được kẹp vào khoảng hợp lệ và ghi xuống ngay.
@MainActor
@Observable
public final class PanelSettings {
    public static let opacityRange: ClosedRange<Double> = 0...1
    public static let widthRange: ClosedRange<Double> = 320...700
    public static let defaultOpacity = 0.75
    public static let defaultCorner = PanelCorner.topRight
    public static let defaultWidth = 460.0
    public static let defaultClickThrough = true
    public static let defaultTranslationEnabled = false

    public enum Key {
        public static let opacity = "panel.backgroundOpacity"
        public static let corner = "panel.corner"
        public static let width = "panel.width"
        public static let clickThrough = "panel.clickThrough"
        public static let customTopLeft = "panel.customTopLeft"
        public static let translationEnabled = "translation.enabled"
    }

    /// Độ mờ nền: 0 = trong suốt hoàn toàn, 1 = đục.
    public var backgroundOpacity: Double {
        didSet {
            let clamped = Self.clamp(backgroundOpacity, to: Self.opacityRange, fallback: Self.defaultOpacity)
            if clamped != backgroundOpacity { backgroundOpacity = clamped; return }
            defaults.set(clamped, forKey: Key.opacity)
        }
    }

    /// Chọn góc thì bỏ vị trí đã kéo, panel về góc đó.
    public var corner: PanelCorner {
        didSet {
            defaults.set(corner.rawValue, forKey: Key.corner)
            customTopLeft = nil
        }
    }

    /// Click xuyên qua panel. Tắt để kéo panel đi chỗ khác.
    public var clickThrough: Bool {
        didSet { defaults.set(clickThrough, forKey: Key.clickThrough) }
    }

    /// Hiện bản dịch tiếng Việt của câu đã sửa dưới phần "Câu đã sửa".
    public var translationEnabled: Bool {
        didSet { defaults.set(translationEnabled, forKey: Key.translationEnabled) }
    }

    /// Góc trên trái của panel do người dùng kéo (toạ độ AppKit). `nil` = đặt theo `corner`.
    public var customTopLeft: CGPoint? {
        didSet {
            guard customTopLeft != oldValue else { return }
            if let point = customTopLeft, point.x.isFinite, point.y.isFinite {
                defaults.set([Double(point.x), Double(point.y)], forKey: Key.customTopLeft)
            } else {
                if customTopLeft != nil { customTopLeft = nil; return }
                defaults.removeObject(forKey: Key.customTopLeft)
            }
        }
    }

    /// Độ rộng panel (pt).
    public var width: Double {
        didSet {
            let clamped = Self.clamp(width, to: Self.widthRange, fallback: Self.defaultWidth)
            if clamped != width { width = clamped; return }
            defaults.set(clamped, forKey: Key.width)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        backgroundOpacity = Self.clamp(
            defaults.object(forKey: Key.opacity) as? Double, to: Self.opacityRange, fallback: Self.defaultOpacity)
        corner = (defaults.string(forKey: Key.corner)).flatMap(PanelCorner.init(rawValue:)) ?? Self.defaultCorner
        width = Self.clamp(
            defaults.object(forKey: Key.width) as? Double, to: Self.widthRange, fallback: Self.defaultWidth)
        clickThrough = defaults.object(forKey: Key.clickThrough) as? Bool ?? Self.defaultClickThrough
        translationEnabled = defaults.object(forKey: Key.translationEnabled) as? Bool ?? Self.defaultTranslationEnabled
        if let pair = defaults.array(forKey: Key.customTopLeft) as? [Double], pair.count == 2,
           pair.allSatisfy(\.isFinite) {
            customTopLeft = CGPoint(x: pair[0], y: pair[1])
        } else {
            customTopLeft = nil
        }
    }

    /// Bỏ vị trí đã kéo, panel về góc đang chọn.
    public func resetPosition() {
        customTopLeft = nil
    }

    public func resetToDefaults() {
        backgroundOpacity = Self.defaultOpacity
        corner = Self.defaultCorner
        width = Self.defaultWidth
        clickThrough = Self.defaultClickThrough
        translationEnabled = Self.defaultTranslationEnabled
        customTopLeft = nil
    }

    private static func clamp(_ value: Double?, to range: ClosedRange<Double>, fallback: Double) -> Double {
        guard let value, value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
