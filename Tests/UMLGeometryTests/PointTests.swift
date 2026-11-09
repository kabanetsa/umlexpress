import XCTest
@testable import UMLGeometry

/// Port of test/org/jetuml/geom/PointTest.java
final class PointTests: XCTestCase {

    private static let zero = Point(x: 0, y: 0)
    private static let one = Point(x: 1, y: 1)
    private static let minusOne = Point(x: -1, y: -1)

    func testToString() {
        XCTAssertEqual("Point[x=0, y=0]", Self.zero.description)
        XCTAssertEqual("Point[x=-1, y=-1]", Self.minusOne.description)
    }

    func testDistance() {
        XCTAssertEqual(0, Self.zero.distance(to: Self.zero), accuracy: 0.0001)
        XCTAssertEqual(1.4142, Self.zero.distance(to: Self.one), accuracy: 0.0001)
        XCTAssertEqual(2.8284, Self.one.distance(to: Self.minusOne), accuracy: 0.0001)
    }

    func testCopy() {
        let point = Point(x: 0, y: 0)
        let copy = point.copy()
        XCTAssertEqual(point.x, copy.x)
        XCTAssertEqual(point.y, copy.y)
    }

    func testEquals() {
        let point1 = Point(x: 0, y: 0)
        let point2 = Point(x: 0, y: 0)
        XCTAssertEqual(point1, point1)
        XCTAssertEqual(point1, point2)
        XCTAssertEqual(point2, point1)
        XCTAssertNotEqual(point1, Point(x: 1, y: 1))
        XCTAssertNotEqual(point1, Point(x: 0, y: 1))
        XCTAssertNotEqual(point1, Point(x: 1, y: 0))
    }
}
