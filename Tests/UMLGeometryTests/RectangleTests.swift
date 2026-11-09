import XCTest
@testable import UMLGeometry

/// Port of test/org/jetuml/geom/RectangleTest.java
final class RectangleTests: XCTestCase {

    private static let rectangle1 = Rectangle(x: 0, y: 0, width: 60, height: 40)
    private static let rectangle2 = Rectangle(x: 100, y: 20, width: 1, height: 1)

    func testToString() {
        XCTAssertEqual("Rectangle[x=0, y=0, width=60, height=40]", Self.rectangle1.description)
    }

    func testMaxXY() {
        XCTAssertEqual(60, Self.rectangle1.maxX)
        XCTAssertEqual(40, Self.rectangle1.maxY)
        XCTAssertEqual(101, Self.rectangle2.maxX)
        XCTAssertEqual(21, Self.rectangle2.maxY)
    }

    func testEquals() {
        XCTAssertEqual(Self.rectangle1, Self.rectangle1)
        XCTAssertEqual(Self.rectangle1, Rectangle(x: 0, y: 0, width: 60, height: 40))
        XCTAssertNotEqual(Self.rectangle1, Self.rectangle2)
    }

    func testTranslated() {
        XCTAssertEqual(Rectangle(x: 10, y: 20, width: 60, height: 40), Self.rectangle1.translated(10, 20))
        XCTAssertEqual(Rectangle(x: -10, y: -20, width: 60, height: 40), Self.rectangle1.translated(-10, -20))
    }

    func testContainsPoint() {
        XCTAssertTrue(Self.rectangle1.contains(Point(x: 10, y: 20)))
        XCTAssertTrue(Self.rectangle1.contains(Point(x: 0, y: 0)))
        XCTAssertTrue(Self.rectangle1.contains(Point(x: 60, y: 0)))
        XCTAssertTrue(Self.rectangle1.contains(Point(x: 0, y: 40)))
        XCTAssertFalse(Self.rectangle1.contains(Point(x: 0, y: 41)))
    }

    func testContainsRectangle() {
        XCTAssertTrue(Self.rectangle1.contains(Rectangle(x: 10, y: 10, width: 10, height: 10)))
        XCTAssertTrue(Self.rectangle1.contains(Rectangle(x: 0, y: 0, width: 60, height: 40)))
        XCTAssertFalse(Self.rectangle1.contains(Rectangle(x: 0, y: 0, width: 61, height: 40)))
        XCTAssertFalse(Self.rectangle1.contains(Rectangle(x: -1, y: 0, width: 10, height: 10)))
    }

    func testGetCenter() {
        var center = Self.rectangle1.center()
        XCTAssertEqual(30, center.x)
        XCTAssertEqual(20, center.y)
        center = Self.rectangle1.translated(10, 10).center()
        XCTAssertEqual(40, center.x)
        XCTAssertEqual(30, center.y)
        center = Self.rectangle2.center()
        XCTAssertEqual(100, center.x)
        XCTAssertEqual(20, center.y)
    }

    func testAddPoint() {
        var rectangle = Rectangle(x: 10, y: 10, width: 0, height: 0)
        rectangle = rectangle.add(Point(x: 20, y: 30))
        XCTAssertEqual(Rectangle(x: 10, y: 10, width: 10, height: 20), rectangle)
        rectangle = rectangle.add(Point(x: 15, y: 15))
        XCTAssertEqual(Rectangle(x: 10, y: 10, width: 10, height: 20), rectangle)
        rectangle = rectangle.add(Point(x: 100, y: 100))
        XCTAssertEqual(Rectangle(x: 10, y: 10, width: 90, height: 90), rectangle)
        rectangle = rectangle.add(Point(x: 0, y: 0))
        XCTAssertEqual(Rectangle(x: 0, y: 0, width: 100, height: 100), rectangle)
    }

    func testAddRectangle() {
        var rectangle = Rectangle(x: 10, y: 10, width: 0, height: 0)
        rectangle = rectangle.add(Rectangle(x: 0, y: 0, width: 20, height: 20))
        XCTAssertEqual(Rectangle(x: 0, y: 0, width: 20, height: 20), rectangle)
    }

    func testCenterSliceSameZeroY() {
        let original = Rectangle(x: 0, y: 0, width: 100, height: 60)
        XCTAssertEqual(Rectangle(x: 0, y: 0, width: 100, height: 60), original.centerSlice(60))
    }

    func testCenterSliceSameNonZeroY() {
        let original = Rectangle(x: 0, y: 20, width: 100, height: 60)
        XCTAssertEqual(Rectangle(x: 0, y: 20, width: 100, height: 60), original.centerSlice(60))
    }

    func testCenterSliceSmaller() {
        let original = Rectangle(x: 0, y: 20, width: 100, height: 60)
        XCTAssertEqual(Rectangle(x: 0, y: 35, width: 100, height: 30), original.centerSlice(30))
    }

    func testOrigin() {
        XCTAssertEqual(Point(x: 0, y: 0), Self.rectangle1.origin())
        XCTAssertEqual(Point(x: 100, y: 20), Self.rectangle2.origin())
    }
}
