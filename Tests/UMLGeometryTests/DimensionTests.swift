import XCTest
@testable import UMLGeometry

/// Port of test/org/jetuml/geom/DimensionTest.java
final class DimensionTests: XCTestCase {

    private static let dim0 = Dimension(width: 0, height: 0)
    private static let dim1 = Dimension(width: 10, height: 10)
    private static let dim2 = Dimension(width: 5, height: 5)
    private static let dim3 = Dimension(width: 10, height: 5)
    private static let dim4 = Dimension(width: 5, height: 10)

    func testToString() {
        XCTAssertEqual("Dimension[width=10, height=10]", Self.dim1.description)
    }

    func testEquals() {
        XCTAssertEqual(Self.dim0, Self.dim0)
        XCTAssertEqual(Self.dim0, Dimension(width: 0, height: 0))
        XCTAssertEqual(Self.dim1, Dimension(width: 10, height: 10))
        XCTAssertEqual(Self.dim2, Dimension(width: 5, height: 5))
        XCTAssertNotEqual(Self.dim0, Self.dim1)
    }

    func testNullConstant() {
        XCTAssertEqual(Dimension(width: 0, height: 0), Dimension.null)
    }

    func testInclude() {
        XCTAssertEqual(Dimension(width: 10, height: 10), Self.dim2.include(10, 10))
        XCTAssertEqual(Dimension(width: 10, height: 5), Self.dim3.include(5, 5))
        XCTAssertEqual(Dimension(width: 5, height: 10), Self.dim4.include(1, 1))
        XCTAssertEqual(Dimension(width: 10, height: 10), Self.dim1.include(0, 0))
    }
}
