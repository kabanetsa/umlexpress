import XCTest
@testable import UMLGeometry

/// Tests for `GridUtils`. The original has no dedicated test class; these cases
/// pin the snapping behaviour used by the canvas.
final class GridUtilsTests: XCTestCase {

    func testSnappedPoint() {
        XCTAssertEqual(Point(x: 0, y: 0), GridUtils.snapped(Point(x: 0, y: 0)))
        XCTAssertEqual(Point(x: 10, y: 10), GridUtils.snapped(Point(x: 9, y: 11)))
        XCTAssertEqual(Point(x: 20, y: 20), GridUtils.snapped(Point(x: 16, y: 15)))
        XCTAssertEqual(Point(x: -10, y: -10), GridUtils.snapped(Point(x: -9, y: -11)))
    }

    func testSnappedRectangle() {
        XCTAssertEqual(
            Rectangle(x: 10, y: 10, width: 20, height: 10),
            GridUtils.snapped(Rectangle(x: 9, y: 8, width: 11, height: 1)))
        XCTAssertEqual(
            Rectangle(x: 0, y: 0, width: 60, height: 40),
            GridUtils.snapped(Rectangle(x: 0, y: 0, width: 60, height: 40)))
    }

    func testSnappedHorizontallyAndVertically() {
        let point = Point(x: 9, y: 7)
        XCTAssertEqual(Point(x: 10, y: 7), GridUtils.snappedHorizontally(point))
        XCTAssertEqual(Point(x: 9, y: 10), GridUtils.snappedVertically(point))
    }

    func testToMultiple() {
        XCTAssertEqual(0, GridUtils.toMultiple(0))
        XCTAssertEqual(10, GridUtils.toMultiple(1))
        XCTAssertEqual(10, GridUtils.toMultiple(9))
        XCTAssertEqual(10, GridUtils.toMultiple(10))
        XCTAssertEqual(20, GridUtils.toMultiple(11))
        XCTAssertEqual(40, GridUtils.toMultiple(31))
    }
}
