//
//  GeomUtils.swift
//  UMLExpress
//
//  Port of org.jetuml.geom.GeomUtils (JetUML 3.10, GPL-3, (C) McGill University).
//  Utility methods for geometric calculations, in particular the intersection of
//  a direction from the centre of a shape with the shape's boundary.
//

import Foundation

/// Namespace for geometric utility functions.
///
/// A `final class` with a private constructor in the original; a caseless enum is the
/// Swift idiom for a namespace. All members are static.
public enum GeomUtils {

    /// The maximum value of all arguments.
    /// - Precondition: `values` is not empty.
    public static func max(_ values: Int...) -> Int {
        precondition(!values.isEmpty)
        var result = Int.min
        for value in values where value > result {
            result = value
        }
        return result
    }

    /// The point where a line from the centre of the rectangle in the given
    /// direction leaves the rectangle.
    public static func intersectRectangle(_ rectangle: Rectangle, _ direction: Direction) -> Point {
        if direction.isCardinal {
            return intersectionForCardinalDirection(rectangle, direction)
        }

        let diagonalNE = Direction.fromLine(
            rectangle.center(), Point(x: rectangle.maxX, y: rectangle.y))
        let diagonalSE = Direction.fromLine(
            rectangle.center(), Point(x: rectangle.maxX, y: rectangle.maxY))
        let diagonalSW = diagonalNE.mirrored()
        let diagonalNW = diagonalSE.mirrored()

        if direction.isBetween(diagonalNE, diagonalSE.rotatedBy(1)) {
            let offset = lengthOfOpposingSide(
                direction.asAngle - Direction.east.asAngle, rectangle.width / 2)
            return Point(x: rectangle.maxX, y: rectangle.center().y + offset)
        } else if direction.isBetween(diagonalSE, diagonalSW.rotatedBy(1)) {
            let offset = lengthOfOpposingSide(
                direction.asAngle - Direction.south.asAngle, rectangle.height / 2)
            return Point(x: rectangle.center().x - offset, y: rectangle.maxY)
        } else if direction.isBetween(diagonalSW, diagonalNW.rotatedBy(1)) {
            let offset = lengthOfOpposingSide(
                direction.asAngle - Direction.west.asAngle, rectangle.width / 2)
            return Point(x: rectangle.x, y: rectangle.center().y - offset)
        } else {
            let angleToNorth = 360
            let offset = lengthOfOpposingSide(
                direction.asAngle - angleToNorth, rectangle.height / 2)
            return Point(x: rectangle.center().x + offset, y: rectangle.y)
        }
    }

    /// The point where a line from the centre of the circle inscribed in `bounds`
    /// in the given direction leaves the circle.
    /// - Precondition: `bounds.width == bounds.height`.
    public static func intersectCircle(_ bounds: Rectangle, _ direction: Direction) -> Point {
        precondition(bounds.width == bounds.height)
        if direction.isCardinal {
            return intersectionForCardinalDirection(bounds, direction)
        }

        let radius = bounds.width / 2
        let angle = direction.asAngle - Direction.east.asAngle
        let offsetX = round(cos(toRadians(angle)) * Double(radius))
        let offsetY = round(sin(toRadians(angle)) * Double(radius))
        return Point(x: bounds.center().x + offsetX, y: bounds.center().y + offsetY)
    }

    /// The point where a line from the centre of the ellipse inscribed in `bounds`
    /// in the given direction leaves the ellipse.
    public static func intersectEllipse(_ bounds: Rectangle, _ direction: Direction) -> Point {
        if direction.isCardinal {
            return intersectionForCardinalDirection(bounds, direction)
        }

        let a = bounds.width / 2
        let b = bounds.height / 2
        let angle = direction.asAngle - Direction.east.asAngle
        let offsetX = round(cos(toRadians(angle)) * Double(a))
        let offsetY = round(sin(toRadians(angle)) * Double(b))
        return Point(x: bounds.center().x + offsetX, y: bounds.center().y + offsetY)
    }

    /// The point where a line from the centre of the rounded rectangle inscribed in
    /// `bounds` in the given direction leaves the rounded rectangle.
    public static func intersectRoundedRectangle(_ bounds: Rectangle, _ direction: Direction) -> Point {
        if direction.isCardinal {
            return intersectionForCardinalDirection(bounds, direction)
        }

        let arcSize = 20 // Same as the value in the original rendering code.
        let radius = arcSize / 2
        let widthOffset = bounds.width / 2 - radius
        let heightOffset = bounds.height / 2 - radius

        let topNE = Direction.fromLine(
            bounds.center(), Point(x: bounds.maxX - radius, y: bounds.y))
        let bottomNE = Direction.fromLine(
            bounds.center(), Point(x: bounds.maxX, y: bounds.y + radius))
        let topSE = Direction.fromLine(
            bounds.center(), Point(x: bounds.maxX, y: bounds.maxY - radius))
        let bottomSE = Direction.fromLine(
            bounds.center(), Point(x: bounds.maxX - radius, y: bounds.maxY))
        let topSW = topNE.mirrored()
        let bottomSW = bottomNE.mirrored()
        let topNW = topSE.mirrored()
        let bottomNW = bottomSE.mirrored()

        let rectangleIntersectionPoint = intersectRectangle(bounds, direction)

        if direction.isBetween(topNE, bottomNE) {
            let cornerCenter = Point(
                x: bounds.center().x + widthOffset, y: bounds.center().y - heightOffset)
            return roundedCornerPoint(cornerCenter, rectangleIntersectionPoint, radius,
                                     xOffset: widthOffset, yOffset: -heightOffset)
        } else if direction.isBetween(topSE, bottomSE) {
            let cornerCenter = Point(
                x: bounds.center().x + widthOffset, y: bounds.center().y + heightOffset)
            return roundedCornerPoint(cornerCenter, rectangleIntersectionPoint, radius,
                                     xOffset: widthOffset, yOffset: heightOffset)
        } else if direction.isBetween(topSW, bottomSW) {
            let cornerCenter = Point(
                x: bounds.center().x - widthOffset, y: bounds.center().y + heightOffset)
            return roundedCornerPoint(cornerCenter, rectangleIntersectionPoint, radius,
                                     xOffset: -widthOffset, yOffset: heightOffset)
        } else if direction.isBetween(topNW, bottomNW) {
            let cornerCenter = Point(
                x: bounds.center().x - widthOffset, y: bounds.center().y - heightOffset)
            return roundedCornerPoint(cornerCenter, rectangleIntersectionPoint, radius,
                                     xOffset: -widthOffset, yOffset: -heightOffset)
        } else {
            return rectangleIntersectionPoint
        }
    }

    /// Rounds a number to the nearest integer, as `Math.round`: ties are rounded
    /// towards positive infinity.
    public static func round(_ value: Double) -> Int {
        precondition(value >= Double(Int.min) && value <= Double(Int.max))
        return Int((value + 0.5).rounded(.down))
    }

    // MARK: - Private

    /// The intersection point for a cardinal direction.
    private static func intersectionForCardinalDirection(
        _ rectangle: Rectangle, _ direction: Direction) -> Point {
        precondition(direction.isCardinal)
        if direction == Direction.north {
            return Point(x: rectangle.center().x, y: rectangle.y)
        } else if direction == Direction.south {
            return Point(x: rectangle.center().x, y: rectangle.maxY)
        } else if direction == Direction.east {
            return Point(x: rectangle.maxX, y: rectangle.center().y)
        } else {
            return Point(x: rectangle.x, y: rectangle.center().y)
        }
    }

    /// The point on the circular arc of a rounded corner that the line from the corner
    /// centre towards `rectangleIntersectionPoint` meets.
    private static func roundedCornerPoint(
        _ cornerCenter: Point, _ rectangleIntersectionPoint: Point, _ radius: Int,
        xOffset: Int, yOffset: Int
    ) -> Point {
        let cornerDirection = Direction.fromLine(cornerCenter, rectangleIntersectionPoint)
        let angle = cornerDirection.asAngle - Direction.east.asAngle
        let offsetX = round(cos(toRadians(angle)) * Double(radius))
        let offsetY = round(sin(toRadians(angle)) * Double(radius))
        return Point(
            x: cornerCenter.x + offsetX,
            y: cornerCenter.y + offsetY
        )
    }

    /// The length in pixels of the side opposing the given angle of a right triangle,
    /// given the length of the adjacent side.
    private static func lengthOfOpposingSide(_ angleInDegrees: Int, _ adjacentSide: Int) -> Int {
        round(Double(adjacentSide) * tan(toRadians(angleInDegrees)))
    }

    /// Degrees to radians, as `Math.toRadians`.
    private static func toRadians(_ degrees: Int) -> Double {
        Double(degrees) * Double.pi / 180.0
    }
}
