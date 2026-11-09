//
//  Rectangle.swift
//  UMLExpress
//
//  Port of org.jetuml.geom.Rectangle (JetUML 3.10, GPL-3, (C) McGill University).
//  A framework-independent rectangle in two-dimensional integer space.
//

/// A rectangle in integer space, defined by its top-left corner and extents.
public struct Rectangle: Hashable, Sendable, CustomStringConvertible {

    /// The x-coordinate of the top-left corner.
    public let x: Int

    /// The y-coordinate of the top-left corner.
    public let y: Int

    /// The width. >= 0
    public let width: Int

    /// The height. >= 0
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The x-coordinate farthest from the origin.
    public var maxX: Int { x + width }

    /// The y-coordinate farthest from the origin.
    public var maxY: Int { y + height }

    /// The rectangle translated by the given deltas.
    public func translated(_ deltaX: Int, _ deltaY: Int) -> Rectangle {
        Rectangle(x: x + deltaX, y: y + deltaY, width: width, height: height)
    }

    /// True iff the point is within the rectangle or on its boundary.
    public func contains(_ point: Point) -> Bool {
        point.x >= x && point.x <= maxX && point.y >= y && point.y <= maxY
    }

    /// True iff the given rectangle is entirely contained within this rectangle.
    public func contains(_ rectangle: Rectangle) -> Bool {
        rectangle.x >= x && rectangle.y >= y
            && rectangle.maxX <= maxX && rectangle.maxY <= maxY
    }

    /// A point at the centre of this rectangle.
    ///
    /// Note: integer division, as in the original.
    public func center() -> Point {
        Point(x: x + width / 2, y: y + height / 2)
    }

    /// A new rectangle that is this rectangle enlarged to include the point.
    public func add(_ point: Point) -> Rectangle {
        var currentX = x
        var currentY = y
        var currentWidth = width
        var currentHeight = height
        if point.x < x {
            currentX = point.x
            currentWidth = maxX - point.x
        } else if point.x > maxX {
            currentWidth = point.x - x
        }
        if point.y < y {
            currentY = point.y
            currentHeight = maxY - point.y
        } else if point.y > maxY {
            currentHeight = point.y - y
        }
        return Rectangle(x: currentX, y: currentY, width: currentWidth, height: currentHeight)
    }

    /// A new rectangle that is this rectangle enlarged to include the given rectangle.
    public func add(_ rectangle: Rectangle) -> Rectangle {
        let currentX = min(x, rectangle.x)
        let currentY = min(y, rectangle.y)
        let newMaxX = max(maxX, rectangle.maxX)
        let newMaxY = max(maxY, rectangle.maxY)
        return Rectangle(
            x: currentX,
            y: currentY,
            width: newMaxX - currentX,
            height: newMaxY - currentY
        )
    }

    /// A rectangle of the given height, centered vertically on this rectangle's centre,
    /// with the same x-coordinate and width.
    public func centerSlice(_ pHeight: Int) -> Rectangle {
        precondition(pHeight >= 0 && pHeight <= height)
        return Rectangle(x: x, y: center().y - pHeight / 2, width: width, height: pHeight)
    }

    /// The top-left corner of the rectangle.
    public func origin() -> Point {
        Point(x: x, y: y)
    }

    /// The smallest rectangle enclosing all the given points.
    public static func spanning(_ points: [Point]) -> Rectangle {
        precondition(!points.isEmpty)
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return Rectangle(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public var description: String {
        "Rectangle[x=\(x), y=\(y), width=\(width), height=\(height)]"
    }
}
