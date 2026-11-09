//
//  Line.swift
//  UMLExpress
//
//  Port of org.jetuml.geom.Line (JetUML 3.10, GPL-3, (C) McGill University).
//  A pair of connected points in integer space.
//

/// A line segment in integer space, defined by two points.
public struct Line: Hashable, Sendable, CustomStringConvertible {

    /// Conceptually the "start" of the line.
    public let point1: Point

    /// Conceptually the "end" of the line.
    public let point2: Point

    public init(point1: Point, point2: Point) {
        self.point1 = point1
        self.point2 = point2
    }

    /// Creates a new line from individual coordinates.
    public init(x1: Int, y1: Int, x2: Int, y2: Int) {
        self.init(point1: Point(x: x1, y: y1), point2: Point(x: x2, y: y2))
    }

    /// The x-coordinate of point 1.
    public var x1: Int { point1.x }

    /// The y-coordinate of point 1.
    public var y1: Int { point1.y }

    /// The x-coordinate of point 2.
    public var x2: Int { point2.x }

    /// The y-coordinate of point 2.
    public var y2: Int { point2.y }

    /// The absolute difference between the x-values as a width and between the
    /// y-values as a height.
    public func distanceBetweenPoints() -> Dimension {
        Dimension(width: abs(x1 - x2), height: abs(y1 - y2))
    }

    /// The same line with the two points reversed.
    public func reversed() -> Line {
        Line(point1: point2, point2: point1)
    }

    /// The point at the centre of the line.
    public func center() -> Point {
        Point(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
    }

    /// True iff the y-value of both points is the same.
    public var isHorizontal: Bool { y1 == y2 }

    /// True iff the x-value of both points is the same.
    public var isVertical: Bool { x1 == x2 }

    /// The rectangle spanning this line.
    public func spanning() -> Rectangle {
        Rectangle(
            x: min(x1, x2),
            y: min(y1, y2),
            width: abs(x2 - x1),
            height: abs(y2 - y1)
        )
    }

    public var description: String {
        "Line[point1=\(point1), point2=\(point2)]"
    }
}
