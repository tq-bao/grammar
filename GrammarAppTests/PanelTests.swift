import XCTest
@testable import GrammarKit

final class PanelLayoutTests: XCTestCase {
    // Vùng hiển thị không bắt đầu ở (0,0): Dock 70 pt ở dưới, menu bar 25 pt ở trên.
    let visible = CGRect(x: 0, y: 70, width: 1440, height: 805)
    let size = CGSize(width: 460, height: 200)

    func testTopRight() {
        let f = PanelLayout.frame(corner: .topRight, size: size, visibleFrame: visible)
        XCTAssertEqual(f, CGRect(x: 1440 - 20 - 460, y: 70 + 805 - 20 - 200, width: 460, height: 200))
    }

    func testTopLeft() {
        let f = PanelLayout.frame(corner: .topLeft, size: size, visibleFrame: visible)
        XCTAssertEqual(f.minX, 20)
        XCTAssertEqual(f.maxY, visible.maxY - 20)
    }

    func testBottomRight() {
        let f = PanelLayout.frame(corner: .bottomRight, size: size, visibleFrame: visible)
        XCTAssertEqual(f.maxX, visible.maxX - 20)
        XCTAssertEqual(f.minY, visible.minY + 20)
    }

    func testBottomLeft() {
        let f = PanelLayout.frame(corner: .bottomLeft, size: size, visibleFrame: visible)
        XCTAssertEqual(f.origin, CGPoint(x: 20, y: 90))
    }

    func testSecondaryScreenOffset() {
        let screen = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let f = PanelLayout.frame(corner: .topLeft, size: size, visibleFrame: screen)
        XCTAssertEqual(f.minX, -1900)
    }

    func testLargerThanScreenIsClamped() {
        let small = CGRect(x: 0, y: 0, width: 400, height: 300)
        let f = PanelLayout.frame(corner: .bottomRight, size: CGSize(width: 700, height: 900), visibleFrame: small)
        XCTAssertEqual(f, CGRect(x: 20, y: 20, width: 360, height: 260))
        XCTAssertTrue(small.contains(f))
    }
}

@MainActor
final class PanelSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "GrammarAppTests.PanelSettings"

    override func setUp() async throws {
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    func testDefaultsWhenEmpty() {
        let s = PanelSettings(defaults: defaults)
        XCTAssertEqual(s.backgroundOpacity, 0.75)
        XCTAssertEqual(s.corner, .topRight)
        XCTAssertEqual(s.width, 460)
    }

    func testValuesPersistAcrossInstances() {
        let s = PanelSettings(defaults: defaults)
        s.backgroundOpacity = 0.3
        s.corner = .bottomLeft
        s.width = 520

        let reloaded = PanelSettings(defaults: defaults)
        XCTAssertEqual(reloaded.backgroundOpacity, 0.3)
        XCTAssertEqual(reloaded.corner, .bottomLeft)
        XCTAssertEqual(reloaded.width, 520)
    }

    func testOutOfRangeValuesAreClamped() {
        defaults.set(5.0, forKey: PanelSettings.Key.opacity)
        defaults.set(10.0, forKey: PanelSettings.Key.width)
        defaults.set("middle", forKey: PanelSettings.Key.corner)
        let s = PanelSettings(defaults: defaults)
        XCTAssertEqual(s.backgroundOpacity, 1.0)
        XCTAssertEqual(s.width, 320)
        XCTAssertEqual(s.corner, .topRight)

        s.backgroundOpacity = -1
        XCTAssertEqual(s.backgroundOpacity, 0)
        s.width = 9999
        XCTAssertEqual(s.width, 700)
        XCTAssertEqual(PanelSettings(defaults: defaults).width, 700)
    }

    func testResetToDefaults() {
        let s = PanelSettings(defaults: defaults)
        s.backgroundOpacity = 0.1
        s.corner = .bottomRight
        s.width = 600
        s.resetToDefaults()
        XCTAssertEqual(s.backgroundOpacity, 0.75)
        XCTAssertEqual(s.corner, .topRight)
        XCTAssertEqual(s.width, 460)
        XCTAssertEqual(PanelSettings(defaults: defaults).corner, .topRight)
    }
}

final class PanelLayoutTopLeftTests: XCTestCase {
    let visible = CGRect(x: 0, y: 70, width: 1440, height: 805)  // maxY = 875
    let size = CGSize(width: 460, height: 200)

    func testKeepsTopLeftWhenItFits() {
        let f = PanelLayout.frame(topLeft: CGPoint(x: 500, y: 600), size: size, visibleFrame: visible)
        XCTAssertEqual(f, CGRect(x: 500, y: 400, width: 460, height: 200))
    }

    func testNearBottomEdgeIsPushedUp() {
        let f = PanelLayout.frame(topLeft: CGPoint(x: 500, y: 150), size: size, visibleFrame: visible)
        XCTAssertEqual(f.minY, visible.minY)
        XCTAssertEqual(f.height, 200)
    }

    func testOutsideScreenIsClampedInside() {
        let f = PanelLayout.frame(topLeft: CGPoint(x: 5000, y: 5000), size: size, visibleFrame: visible)
        XCTAssertTrue(visible.contains(f))
        XCTAssertEqual(f.maxX, visible.maxX)
        XCTAssertEqual(f.maxY, visible.maxY)
    }
}

@MainActor
final class PanelSettingsClickThroughTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "GrammarAppTests.PanelSettings.ClickThrough"

    override func setUp() async throws {
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    func testDefaults() {
        let s = PanelSettings(defaults: defaults)
        XCTAssertTrue(s.clickThrough)
        XCTAssertNil(s.customTopLeft)
    }

    func testClickThroughAndPositionPersist() {
        let s = PanelSettings(defaults: defaults)
        s.clickThrough = false
        s.customTopLeft = CGPoint(x: 300, y: 700)

        let reloaded = PanelSettings(defaults: defaults)
        XCTAssertFalse(reloaded.clickThrough)
        XCTAssertEqual(reloaded.customTopLeft, CGPoint(x: 300, y: 700))
    }

    func testChoosingCornerClearsDraggedPosition() {
        let s = PanelSettings(defaults: defaults)
        s.customTopLeft = CGPoint(x: 300, y: 700)
        s.corner = .bottomLeft
        XCTAssertNil(s.customTopLeft)
        XCTAssertNil(PanelSettings(defaults: defaults).customTopLeft)
    }

    func testResetPositionAndResetToDefaults() {
        let s = PanelSettings(defaults: defaults)
        s.customTopLeft = CGPoint(x: 1, y: 2)
        s.resetPosition()
        XCTAssertNil(s.customTopLeft)

        s.clickThrough = false
        s.customTopLeft = CGPoint(x: 1, y: 2)
        s.resetToDefaults()
        XCTAssertTrue(s.clickThrough)
        XCTAssertNil(s.customTopLeft)
    }

    func testInvalidStoredPositionIsIgnored() {
        defaults.set(["a", "b"], forKey: PanelSettings.Key.customTopLeft)
        XCTAssertNil(PanelSettings(defaults: defaults).customTopLeft)
        defaults.set([1.0], forKey: PanelSettings.Key.customTopLeft)
        XCTAssertNil(PanelSettings(defaults: defaults).customTopLeft)
    }
}

final class PanelHeaderTests: XCTestCase {
    let panel = CGRect(x: 100, y: 200, width: 460, height: 180)  // maxY = 380

    func testHeaderIsTopStrip() {
        XCTAssertEqual(PanelLayout.headerRect(in: panel), CGRect(x: 100, y: 356, width: 460, height: 24))
    }

    func testPointsInsideAndOutsideHeader() {
        let header = PanelLayout.headerRect(in: panel)
        XCTAssertTrue(header.contains(CGPoint(x: 300, y: 370)))   // trong header
        XCTAssertTrue(header.contains(CGPoint(x: 101, y: 356)))   // mép dưới header
        XCTAssertFalse(header.contains(CGPoint(x: 300, y: 355)))  // ngay dưới header: phần nội dung
        XCTAssertFalse(header.contains(CGPoint(x: 300, y: 380)))  // mép trên (ngoài khung)
        XCTAssertFalse(header.contains(CGPoint(x: 99, y: 370)))   // bên trái panel
    }

    func testVeryShortPanel() {
        let tiny = CGRect(x: 0, y: 0, width: 100, height: 10)
        XCTAssertEqual(PanelLayout.headerRect(in: tiny), tiny)
    }
}
