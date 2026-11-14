// Vẽ icon app Grammar (1024×1024) rồi xuất đủ kích thước cho AppIcon.appiconset.
//
//   swift scripts/make-icon.swift
//
// Ý tưởng: chữ "Aa" trắng trên nền gradient xanh dương → tím, gạch lượn sóng đỏ (lỗi ngữ pháp)
// và huy hiệu tròn xanh lá có dấu ✓ (đã sửa).
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("GrammarApp/Resources/Assets.xcassets/AppIcon.appiconset")

func draw(size: Int) -> Data {
    let s = CGFloat(size)
    let k = s / 1024  // hệ số tỉ lệ theo canvas 1024
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Khung icon macOS: 824×824 giữa canvas 1024, bo góc ~185.
    let tile = CGRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * k, yRadius: 185 * k)

    // Bóng đổ nhẹ dưới khung.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * k), blur: 28 * k,
                  color: NSColor.black.withAlphaComponent(0.30).cgColor)
    NSColor.black.setFill()
    tilePath.fill()
    ctx.restoreGState()

    // Nền gradient xanh dương (trên) → tím (dưới).
    ctx.saveGState()
    tilePath.addClip()
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.18, green: 0.45, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.42, green: 0.27, blue: 0.90, alpha: 1),
    ])!
    gradient.draw(in: tile, angle: -90)

    // Ánh sáng mờ ở nửa trên cho cảm giác có chiều sâu.
    let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
    gloss.draw(in: CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
    ctx.restoreGState()

    // Chữ "Aa" trắng, font tròn đậm.
    let base = NSFont.systemFont(ofSize: 430 * k, weight: .heavy)
    let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: 430 * k) ?? base
    let text = NSAttributedString(string: "Aa", attributes: [
        .font: font,
        .foregroundColor: NSColor.white,
    ])
    let textSize = text.size()
    let textOrigin = CGPoint(x: (s - textSize.width) / 2, y: 405 * k)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * k), blur: 14 * k,
                  color: NSColor.black.withAlphaComponent(0.22).cgColor)
    text.draw(at: textOrigin)
    ctx.restoreGState()

    // Gạch lượn sóng đỏ dưới chữ.
    let wave = NSBezierPath()
    let waveY = 345 * k
    let startX = 252 * k, endX = 772 * k
    let period = 104 * k, amplitude = 16 * k
    wave.move(to: CGPoint(x: startX, y: waveY))
    var x = startX
    var up = true
    while x < endX {
        let next = min(x + period / 2, endX)
        wave.curve(to: CGPoint(x: next, y: waveY),
                   controlPoint1: CGPoint(x: x + period / 6, y: waveY + (up ? amplitude : -amplitude) * 1.3),
                   controlPoint2: CGPoint(x: next - period / 6, y: waveY + (up ? amplitude : -amplitude) * 1.3))
        x = next
        up.toggle()
    }
    wave.lineWidth = 30 * k
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    NSColor(srgbRed: 1.0, green: 0.30, blue: 0.33, alpha: 1).setStroke()
    wave.stroke()

    // Huy hiệu tròn xanh lá có dấu ✓ ở góc dưới phải.
    let badge = CGRect(x: 640 * k, y: 140 * k, width: 230 * k, height: 230 * k)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * k), blur: 16 * k,
                  color: NSColor.black.withAlphaComponent(0.30).cgColor)
    NSColor(srgbRed: 0.16, green: 0.78, blue: 0.42, alpha: 1).setFill()
    NSBezierPath(ovalIn: badge).fill()
    ctx.restoreGState()
    NSColor.white.setStroke()
    let ring = NSBezierPath(ovalIn: badge.insetBy(dx: 6 * k, dy: 6 * k))
    ring.lineWidth = 12 * k
    ring.stroke()

    let check = NSBezierPath()
    check.move(to: CGPoint(x: badge.minX + 62 * k, y: badge.minY + 118 * k))
    check.line(to: CGPoint(x: badge.minX + 100 * k, y: badge.minY + 78 * k))
    check.line(to: CGPoint(x: badge.minX + 170 * k, y: badge.minY + 156 * k))
    check.lineWidth = 30 * k
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Các kích thước macOS cần: (cỡ điểm, scale) -> số pixel.
let entries: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
var images: [[String: String]] = []
for entry in entries {
    let pixels = entry.points * entry.scale
    let name = "icon_\(entry.points)x\(entry.points)\(entry.scale == 2 ? "@2x" : "").png"
    try draw(size: pixels).write(to: iconset.appendingPathComponent(name))
    images.append([
        "filename": name, "idiom": "mac",
        "scale": "\(entry.scale)x", "size": "\(entry.points)x\(entry.points)",
    ])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconset.appendingPathComponent("Contents.json"))

let catalogContents = iconset.deletingLastPathComponent().appendingPathComponent("Contents.json")
try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8).write(to: catalogContents)

print("Đã tạo icon tại \(iconset.path)")
