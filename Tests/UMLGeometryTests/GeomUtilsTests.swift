import XCTest
@testable import UMLGeometry

/// Port of test/org/jetuml/geom/GeomUtilsTest.java
final class GeomUtilsTests: XCTestCase {

    private let rectangle = Rectangle(x: 0, y: 0, width: 60, height: 40)
    private let square = Rectangle(x: 0, y: 0, width: 20, height: 20)

    // MARK: - max

    func testMaxBottom() {
        // Integer.MIN_VALUE in the original (Java int).
        XCTAssertEqual(Int(Int32.min), GeomUtils.max(Int(Int32.min)))
    }

    func testMaxTop() {
        // Integer.MAX_VALUE in the original (Java int).
        XCTAssertEqual(Int(Int32.max), GeomUtils.max(Int(Int32.max)))
    }

    func testMaxSingleNegative() {
        XCTAssertEqual(-5, GeomUtils.max(-5))
    }

    func testMaxSinglePositive() {
        XCTAssertEqual(5, GeomUtils.max(5))
    }

    func testMaxNegativesOnly() {
        XCTAssertEqual(-5, GeomUtils.max(-30, -5, -20, -13))
    }

    func testMaxPositivesOnly() {
        XCTAssertEqual(4000, GeomUtils.max(20, 4000, 34, 34, 50))
    }

    func testMaxMix() {
        XCTAssertEqual(4000, GeomUtils.max(-50, 20, -300, -300, 4000, 34, 4000, 34, 50))
    }

    // MARK: - intersectRectangle

    func testIntersectRectangleCardinals() {
        XCTAssertEqual(Point(x: 30, y: 0), GeomUtils.intersectRectangle(rectangle, .north))
        XCTAssertEqual(Point(x: 60, y: 20), GeomUtils.intersectRectangle(rectangle, .east))
        XCTAssertEqual(Point(x: 30, y: 40), GeomUtils.intersectRectangle(rectangle, .south))
        XCTAssertEqual(Point(x: 0, y: 20), GeomUtils.intersectRectangle(rectangle, .west))
    }

    func testIntersectRectangleEastSide() {
        XCTAssertEqual(Point(x: 60, y: 12),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(75)))
        XCTAssertEqual(Point(x: 60, y: 28),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(105)))
    }

    func testIntersectRectangleBottom() {
        XCTAssertEqual(Point(x: 35, y: 40),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(165)))
        XCTAssertEqual(Point(x: 25, y: 40),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(195)))
    }

    func testIntersectRectangleWestSide() {
        XCTAssertEqual(Point(x: 0, y: 28),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(255)))
        XCTAssertEqual(Point(x: 0, y: 12),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(285)))
    }

    func testIntersectRectangleTop() {
        XCTAssertEqual(Point(x: 25, y: 0),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(345)))
        XCTAssertEqual(Point(x: 35, y: 0),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(15)))
    }

    func testIntersectRectangleCorners() {
        XCTAssertEqual(Point(x: 60, y: 0),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(56)))
        XCTAssertEqual(Point(x: 60, y: 40),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(124)))
        XCTAssertEqual(Point(x: 0, y: 40),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(236)))
        XCTAssertEqual(Point(x: 0, y: 0),
                       GeomUtils.intersectRectangle(rectangle, Direction.fromAngle(304)))
    }

    // MARK: - intersectCircle

    func testIntersectCircleCardinals() {
        XCTAssertEqual(Point(x: 10, y: 0), GeomUtils.intersectCircle(square, .north))
        XCTAssertEqual(Point(x: 20, y: 10), GeomUtils.intersectCircle(square, .east))
        XCTAssertEqual(Point(x: 10, y: 20), GeomUtils.intersectCircle(square, .south))
        XCTAssertEqual(Point(x: 0, y: 10), GeomUtils.intersectCircle(square, .west))
    }

    func testIntersectCircleDiagonals() {
        XCTAssertEqual(Point(x: 19, y: 7),
                       GeomUtils.intersectCircle(square, Direction.fromAngle(70)))
        XCTAssertEqual(Point(x: 19, y: 13),
                       GeomUtils.intersectCircle(square, Direction.fromAngle(110)))
        XCTAssertEqual(Point(x: 3, y: 17),
                       GeomUtils.intersectCircle(square, Direction.fromAngle(225)))
        XCTAssertEqual(Point(x: 2, y: 4),
                       GeomUtils.intersectCircle(square, Direction.fromAngle(305)))
    }

    // MARK: - intersectEllipse

    func testIntersectEllipseCardinals() {
        XCTAssertEqual(Point(x: 30, y: 0), GeomUtils.intersectEllipse(rectangle, .north))
        XCTAssertEqual(Point(x: 60, y: 20), GeomUtils.intersectEllipse(rectangle, .east))
        XCTAssertEqual(Point(x: 30, y: 40), GeomUtils.intersectEllipse(rectangle, .south))
        XCTAssertEqual(Point(x: 0, y: 20), GeomUtils.intersectEllipse(rectangle, .west))
    }

    func testIntersectEllipseDiagonals() {
        XCTAssertEqual(Point(x: 58, y: 13),
                       GeomUtils.intersectEllipse(rectangle, Direction.fromAngle(70)))
        XCTAssertEqual(Point(x: 58, y: 27),
                       GeomUtils.intersectEllipse(rectangle, Direction.fromAngle(110)))
        XCTAssertEqual(Point(x: 9, y: 34),
                       GeomUtils.intersectEllipse(rectangle, Direction.fromAngle(225)))
        XCTAssertEqual(Point(x: 5, y: 9),
                       GeomUtils.intersectEllipse(rectangle, Direction.fromAngle(305)))
    }

    // MARK: - intersectRoundedRectangle

    func testIntersectRoundedRectangleCardinals() {
        XCTAssertEqual(Point(x: 30, y: 0), GeomUtils.intersectRoundedRectangle(rectangle, .north))
        XCTAssertEqual(Point(x: 60, y: 20), GeomUtils.intersectRoundedRectangle(rectangle, .east))
        XCTAssertEqual(Point(x: 30, y: 40), GeomUtils.intersectRoundedRectangle(rectangle, .south))
        XCTAssertEqual(Point(x: 0, y: 20), GeomUtils.intersectRoundedRectangle(rectangle, .west))
    }

    func testIntersectRoundedRectangleDiagonals() {
        XCTAssertEqual(Point(x: 60, y: 9),
                       GeomUtils.intersectRoundedRectangle(rectangle, Direction.fromAngle(70)))
        XCTAssertEqual(Point(x: 60, y: 31),
                       GeomUtils.intersectRoundedRectangle(rectangle, Direction.fromAngle(110)))
        XCTAssertEqual(Point(x: 10, y: 40),
                       GeomUtils.intersectRoundedRectangle(rectangle, Direction.fromAngle(225)))
        XCTAssertEqual(Point(x: 3, y: 3),
                       GeomUtils.intersectRoundedRectangle(rectangle, Direction.fromAngle(305)))
    }

    // MARK: - round (Math.round semantics: ties towards positive infinity)

    func testRoundPositive() {
        XCTAssertEqual(5, GeomUtils.round(5.0))
        XCTAssertEqual(5, GeomUtils.round(5.1))
        XCTAssertEqual(5, GeomUtils.round(5.11))
        XCTAssertEqual(5, GeomUtils.round(5.4999999))
        XCTAssertEqual(6, GeomUtils.round(5.5))
        XCTAssertEqual(6, GeomUtils.round(5.6))
        XCTAssertEqual(6, GeomUtils.round(5.6991))
        XCTAssertEqual(Int(Int32.max), GeomUtils.round(Double(Int32.max)))
    }

    func testRoundNegative() {
        XCTAssertEqual(-5, GeomUtils.round(-5.0))
        XCTAssertEqual(-6, GeomUtils.round(-5.6))
        XCTAssertEqual(-6, GeomUtils.round(-5.611))
        XCTAssertEqual(-6, GeomUtils.round(-5.5000001))
        XCTAssertEqual(-5, GeomUtils.round(-5.5))
        XCTAssertEqual(-5, GeomUtils.round(-5.4))
    }
}
