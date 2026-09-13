import XCTest
@testable import ScreenScan

/// The y-flip between AppKit and Core Graphics is the highest-risk maths in the app, and a
/// sign error there is invisible on a single-display setup. These fixtures are all computed
/// by hand and need no attached display.
final class ScreenGeometryTests: XCTestCase {
    // A 1920x1080 primary display: AppKit frame (0, 0, 1920, 1080).
    private let primaryHeight: CGFloat = 1080

    func testDragIsNormalizedRegardlessOfDirection() {
        let downRight = ScreenGeometry.rect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 60, y: 100))
        let upLeft = ScreenGeometry.rect(from: CGPoint(x: 60, y: 100), to: CGPoint(x: 10, y: 20))

        XCTAssertEqual(downRight, CGRect(x: 10, y: 20, width: 50, height: 80))
        XCTAssertEqual(downRight, upLeft)
    }

    func testStrayClicksAreRejected() {
        XCTAssertFalse(ScreenGeometry.isUsable(CGRect(x: 0, y: 0, width: 1, height: 1)))
        XCTAssertFalse(ScreenGeometry.isUsable(CGRect(x: 0, y: 0, width: 4, height: 400)))
        XCTAssertTrue(ScreenGeometry.isUsable(CGRect(x: 0, y: 0, width: 5, height: 5)))
    }

    func testConversionOnPrimaryDisplay() {
        // Top edge sits at AppKit y = 1000, which is 80pt down from the top of the display.
        let appKit = CGRect(x: 100, y: 900, width: 200, height: 100)

        let coreGraphics = ScreenGeometry.convertToCoreGraphics(rect: appKit,
                                                                primaryScreenHeight: primaryHeight)

        XCTAssertEqual(coreGraphics, CGRect(x: 100, y: 80, width: 200, height: 100))
    }

    func testRectAtTopOfPrimaryDisplayConvertsToZero() {
        let appKit = CGRect(x: 0, y: 1000, width: 50, height: 80) // maxY == 1080, the very top

        let coreGraphics = ScreenGeometry.convertToCoreGraphics(rect: appKit,
                                                                primaryScreenHeight: primaryHeight)

        XCTAssertEqual(coreGraphics.origin.y, 0)
    }

    func testDisplayAbovePrimaryProducesNegativeCoreGraphicsY() {
        // Secondary stacked above primary: AppKit frame (0, 1080, 1920, 1080), which in Core
        // Graphics space is (0, -1080, 1920, 1080).
        let appKit = CGRect(x: 10, y: 1100, width: 50, height: 50)

        let coreGraphics = ScreenGeometry.convertToCoreGraphics(rect: appKit,
                                                                primaryScreenHeight: primaryHeight)
        XCTAssertEqual(coreGraphics, CGRect(x: 10, y: -70, width: 50, height: 50))

        let source = ScreenGeometry.sourceRect(forGlobalRect: coreGraphics,
                                               displayBounds: CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        // 1010pt down that display, i.e. near its bottom — and crucially non-negative.
        XCTAssertEqual(source, CGRect(x: 10, y: 1010, width: 50, height: 50))
    }

    func testDisplayLeftOfPrimaryProducesNonNegativeSourceRect() {
        // Secondary to the left: AppKit and Core Graphics frame (-1920, 0, 1920, 1080).
        let appKit = CGRect(x: -1900, y: 1000, width: 100, height: 80)

        let coreGraphics = ScreenGeometry.convertToCoreGraphics(rect: appKit,
                                                                primaryScreenHeight: primaryHeight)
        let source = ScreenGeometry.sourceRect(forGlobalRect: coreGraphics,
                                               displayBounds: CGRect(x: -1920, y: 0, width: 1920, height: 1080))

        XCTAssertEqual(source, CGRect(x: 20, y: 0, width: 100, height: 80))
    }

    func testPixelSizeFollowsBackingScaleFactor() {
        XCTAssertEqual(ScreenGeometry.pixelSize(for: CGSize(width: 100, height: 50), scaleFactor: 1).width, 100)
        XCTAssertEqual(ScreenGeometry.pixelSize(for: CGSize(width: 100.4, height: 50.5), scaleFactor: 2).width, 201)
        XCTAssertEqual(ScreenGeometry.pixelSize(for: CGSize(width: 100.4, height: 50.5), scaleFactor: 2).height, 101)
    }

    func testPixelSizeNeverCollapsesToZero() {
        let size = ScreenGeometry.pixelSize(for: CGSize(width: 0, height: 0), scaleFactor: 2)
        XCTAssertEqual(size.width, 1)
        XCTAssertEqual(size.height, 1)
    }
}
