import Foundation
import XCTest
@testable import UMLGeometry

/// Port of test/org/jetuml/geom/DirectionTest.java
final class DirectionTests: XCTestCase {

    /// Angles 0...499 as lines of length 100 from the origin: the computed direction
    /// must report the angle modulo 360.
    func testAllAngles() {
        for angle in 0..<500 {
            let radians = Double(angle) * Double.pi / 180.0
            let x = GeomUtils.round(sin(radians) * 100)
            let y = -GeomUtils.round(cos(radians) * 100)
            let direction = Direction.fromLine(Point(x: 0, y: 0), Point(x: x, y: y))
            XCTAssertEqual(angle % 360, direction.asAngle, "angle \(angle)")
            XCTAssertEqual(sin(radians), getX(direction), accuracy: 1e-9, "angle \(angle)")
            XCTAssertEqual(-cos(radians), getY(direction), accuracy: 1e-9, "angle \(angle)")
        }
    }

    func testRotate() {
        for angle in stride(from: 0, to: 500, by: 25) {
            XCTAssertEqual(angle % 360, Direction.north.rotatedBy(angle).asAngle, "rotate \(angle)")
        }
    }

    func testIsCardinal() {
        XCTAssertTrue(Direction.north.isCardinal)
        XCTAssertTrue(Direction.east.isCardinal)
        XCTAssertTrue(Direction.south.isCardinal)
        XCTAssertTrue(Direction.west.isCardinal)
        XCTAssertFalse(Direction.fromAngle(15).isCardinal)
    }

    func testToString() {
        XCTAssertEqual("[Direction: 0 degrees]", Direction.north.description)
    }

    func testFlyweight() {
        XCTAssertTrue(Direction.north === Direction.fromLine(Point(x: 0, y: 0), Point(x: 0, y: -1)))
        XCTAssertTrue(Direction.east === Direction.fromLine(Point(x: 0, y: 0), Point(x: 1, y: 0)))
        XCTAssertTrue(Direction.south === Direction.fromLine(Point(x: 0, y: 0), Point(x: 0, y: 1)))
        XCTAssertTrue(Direction.west === Direction.fromLine(Point(x: 0, y: 0), Point(x: -1, y: 0)))
        XCTAssertTrue(Direction.north === Direction.fromAngle(0))
    }

    func testMirrored() {
        XCTAssertEqual(Direction.south, Direction.north.mirrored())
        XCTAssertEqual(Direction.north, Direction.south.mirrored())
        XCTAssertEqual(Direction.west, Direction.east.mirrored())
        XCTAssertEqual(Direction.east, Direction.west.mirrored())
        XCTAssertEqual(Direction.fromAngle(10), Direction.fromAngle(190).mirrored())
    }

    func testIsBetweenTrue() {
        let cases: [(Int, Int, Int)] = [
            (0, 5, 10), // Quadrant 1 clockwise
            (10, 5, 0), // Quadrant 1 counter-clockwise
            (50, 60, 70), // Q2C
            (70, 60, 40), // Q2CC
            (100, 101, 102), // Q3C
            (102, 101, 100), // Q3CC
            (280, 290, 300), // Q4C
            (300, 290, 280), // Q4CC
            (5, 45, 80), // Crossing Q1Q2 C
            (80, 45, 5), // Crossing Q1Q2 CC
            (45, 90, 100), // Crossing Q2Q3 C
            (100, 90, 45), // Crossing Q2Q3 CC
            (100, 180, 270), // Crossing Q3Q4 C
            (270, 180, 100), // Crossing Q3Q4 CC
            (290, 5, 45), // Crossing Q4Q1 C
            (45, 5, 290), // Crossing Q4Q1 CC
            (44, 45, 46), // Q1Q2 boundary C
            (46, 45, 44), // Q1Q2 boundary CC
            (89, 90, 91), // Q2Q3 boundary C
            (91, 90, 89), // Q2Q3 boundary CC
            (179, 180, 181), // Q3Q4 boundary C
            (181, 180, 179), // Q3Q4 boundary CC
            (359, 0, 1), // Q4Q1 boundary C
            (1, 0, 359), // Q4Q1 boundary CC
        ]
        for (start, target, end) in cases {
            XCTAssertTrue(
                Direction.fromAngle(target)
                    .isBetween(Direction.fromAngle(start), Direction.fromAngle(end)),
                "\(start)..\(target)..\(end)")
        }
    }

    func testIsBetweenFromOpposites() {
        XCTAssertFalse(Direction.fromAngle(270).isBetween(Direction.north, Direction.south))
        XCTAssertFalse(Direction.fromAngle(270).isBetween(Direction.south, Direction.north))
        XCTAssertFalse(Direction.fromAngle(270).isBetween(Direction.east, Direction.west))
        XCTAssertFalse(Direction.fromAngle(270).isBetween(Direction.west, Direction.east))
        for angle in 0..<360 {
            XCTAssertFalse(
                Direction.fromAngle((angle + 45) % 360)
                    .isBetween(
                        Direction.fromAngle(angle),
                        Direction.fromAngle((angle + 180) % 360)),
                "opposites at \(angle)")
        }
    }

    func testIsWesterly() {
        for angle in [181, 182, 183, 190, 200, 210, 220, 230, 240, 250, 260, 270, 280,
                      290, 300, 310, 320, 330, 340, 350, 355, 356, 357, 358, 359] {
            XCTAssertTrue(Direction.fromAngle(angle).isWesterly, "\(angle)")
        }
        for angle in [0, 1, 2, 3, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120,
                      130, 140, 150, 160, 170, 175, 176, 177, 178, 179, 180] {
            XCTAssertFalse(Direction.fromAngle(angle).isWesterly, "\(angle)")
        }
    }

    func testIsEasterly() {
        for angle in [1, 2, 3, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130,
                      140, 150, 160, 170, 175, 178, 179] {
            XCTAssertTrue(Direction.fromAngle(angle).isEasterly, "\(angle)")
        }
        for angle in [180, 181, 190, 200, 210, 220, 230, 240, 250, 260, 270, 280, 290, 300,
                      310, 320, 330, 340, 350, 355, 356, 358, 359, 0] {
            XCTAssertFalse(Direction.fromAngle(angle).isEasterly, "\(angle)")
        }
    }

    func testIsNortherly() {
        for angle in [271, 272, 273, 275, 280, 290, 300, 310, 320, 330, 340, 350, 355, 359,
                      0, 1, 2, 3, 5, 10, 20, 30, 40, 50, 60, 70, 80, 85, 87, 88, 89] {
            XCTAssertTrue(Direction.fromAngle(angle).isNortherly, "\(angle)")
        }
        for angle in [90, 91, 92, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210,
                      220, 230, 240, 250, 260, 265, 268, 269, 270] {
            XCTAssertFalse(Direction.fromAngle(angle).isNortherly, "\(angle)")
        }
    }

    func testIsSoutherly() {
        for angle in [91, 92, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210,
                      220, 230, 240, 250, 260, 265, 266, 267, 268, 269] {
            XCTAssertTrue(Direction.fromAngle(angle).isSoutherly, "\(angle)")
        }
        for angle in [270, 271, 280, 290, 300, 310, 320, 330, 340, 350, 0, 10, 20, 30, 40,
                      50, 60, 70, 80, 85, 87, 88, 89, 90] {
            XCTAssertFalse(Direction.fromAngle(angle).isSoutherly, "\(angle)")
        }
    }

    // MARK: - Helpers (as in the original test)

    private func getX(_ direction: Direction) -> Double {
        sin(toRadians(direction.asAngle))
    }

    private func getY(_ direction: Direction) -> Double {
        -cos(toRadians(direction.asAngle))
    }

    private func toRadians(_ degrees: Int) -> Double {
        Double(degrees) * Double.pi / 180.0
    }
}
