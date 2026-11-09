import XCTest
@testable import UMLGeometry

/// Port of test/org/jetuml/geom/LineTest.java
final class LineTests: XCTestCase {

    private static let zero = Point(x: 0, y: 0)
    private static let one = Point(x: 1, y: 1)
    private static let zeroToOne = Line(point1: zero, point2: one)

    func testToString() {
        XCTAssertEqual("Line[point1=Point[x=0, y=0], point2=Point[x=1, y=1]]", Self.zeroToOne.description)
    }

    func testConstructionWithPoints() {
        let zeroAtOrigin = Line(point1: Self.zero, point2: Self.zero)
        XCTAssertEqual(0, zeroAtOrigin.x1)
        XCTAssertEqual(0, zeroAtOrigin.y1)
        XCTAssertEqual(0, zeroAtOrigin.x2)
        XCTAssertEqual(0, zeroAtOrigin.y2)

        let zeroNotAtOrigin = Line(point1: Self.one, point2: Self.one)
        XCTAssertEqual(1, zeroNotAtOrigin.x1)
        XCTAssertEqual(1, zeroNotAtOrigin.y1)
        XCTAssertEqual(1, zeroNotAtOrigin.x2)
        XCTAssertEqual(1, zeroNotAtOrigin.y2)

        XCTAssertEqual(0, Self.zeroToOne.x1)
        XCTAssertEqual(0, Self.zeroToOne.y1)
        XCTAssertEqual(1, Self.zeroToOne.x2)
        XCTAssertEqual(1, Self.zeroToOne.y2)
    }

    func testConstructionWithCoordinates() {
        let line = Line(x1: 3, y1: 4, x2: 13, y2: 9)
        XCTAssertEqual(3, line.x1)
        XCTAssertEqual(4, line.y1)
        XCTAssertEqual(13, line.x2)
        XCTAssertEqual(9, line.y2)
        XCTAssertEqual(Point(x: 3, y: 4), line.point1)
        XCTAssertEqual(Point(x: 13, y: 9), line.point2)
    }

    func testDistanceBetweenPoints() {
        XCTAssertEqual(Dimension(width: 10, height: 5),
                       Line(x1: 3, y1: 4, x2: 13, y2: 9).distanceBetweenPoints())
        XCTAssertEqual(Dimension(width: 10, height: 5),
                       Line(x1: 13, y1: 9, x2: 3, y2: 4).distanceBetweenPoints())
        XCTAssertEqual(Dimension(width: 0, height: 0),
                       Line(point1: Self.one, point2: Self.one).distanceBetweenPoints())
    }

    func testReversed() {
        let line = Line(x1: 3, y1: 4, x2: 13, y2: 9)
        XCTAssertEqual(Line(point1: Point(x: 13, y: 9), point2: Point(x: 3, y: 4)), line.reversed())
        XCTAssertEqual(line, line.reversed().reversed())
    }

    func testCenter() {
        XCTAssertEqual(Point(x: 8, y: 6), Line(x1: 3, y1: 4, x2: 13, y2: 9).center())
        // Integer division, as in the original.
        XCTAssertEqual(Point(x: 0, y: 0), Self.zeroToOne.center())
    }

    func testIsHorizontal() {
        XCTAssertTrue(Line(x1: 0, y1: 5, x2: 10, y2: 5).isHorizontal)
        XCTAssertFalse(Line(x1: 0, y1: 5, x2: 10, y2: 6).isHorizontal)
        XCTAssertTrue(Line(point1: Self.zero, point2: Self.zero).isHorizontal)
    }

    func testIsVertical() {
        XCTAssertTrue(Line(x1: 5, y1: 0, x2: 5, y2: 10).isVertical)
        XCTAssertFalse(Line(x1: 5, y1: 0, x2: 6, y2: 10).isVertical)
        XCTAssertTrue(Line(point1: Self.zero, point2: Self.zero).isVertical)
    }

    func testSpanning() {
        XCTAssertEqual(Rectangle(x: 3, y: 4, width: 10, height: 5),
                       Line(x1: 3, y1: 4, x2: 13, y2: 9).spanning())
        XCTAssertEqual(Rectangle(x: 3, y: 4, width: 10, height: 5),
                       Line(x1: 13, y1: 9, x2: 3, y2: 4).spanning())
        XCTAssertEqual(Rectangle(x: 1, y: 1, width: 0, height: 0),
                       Line(point1: Self.one, point2: Self.one).spanning())
    }
}
