//
//  Point.swift
//  UMLExpress
//
//  Port of org.jetuml.geom.Point (JetUML 3.10, GPL-3, (C) McGill University).
//  A framework-independent representation of a point in integer space.
//

/// A point in integer space.
///
/// Corresponds to the Java record `org.jetuml.geom.Point`. Values are immutable,
/// matching the `@Immutable` annotation of the original.
public struct Point: Hashable, Sendable, CustomStringConvertible {

    /// The x-coordinate of the point.
    public let x: Int

    /// The y-coordinate of the point.
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// The distance between two points.
    public func distance(to point: Point) -> Double {
        let a = point.y - y
        let b = point.x - x
        return (Double(a * a + b * b)).squareRoot()
    }

    /// A copy of this point.
    public func copy() -> Point {
        Point(x: x, y: y)
    }

    public var description: String {
        "Point[x=\(x), y=\(y)]"
    }
}
