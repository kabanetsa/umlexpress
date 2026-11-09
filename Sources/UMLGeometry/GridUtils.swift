//
//  GridUtils.swift
//  UMLExpress
//
//  Port of org.jetuml.geom.GridUtils (JetUML 3.10, GPL-3, (C) McGill University).
//  A grid to which points and rectangles can be "snapped".
//

import Foundation

/// Snapping of points and rectangles to a regular grid.
///
/// A `final class` with a private constructor in the original; a caseless enum is the
/// Swift idiom for a namespace.
public enum GridUtils {

    /// The grid pitch, in pixels. Port of `GridUtils.GRID_SIZE`.
    static let gridSize: Double = 10

    /// The rectangle snapped to the nearest grid point: the origin is rounded, the
    /// extents are rounded up.
    public static func snapped(_ rectangle: Rectangle) -> Rectangle {
        let x = Int(Double(GeomUtils.round(Double(rectangle.x) / gridSize)) * gridSize)
        let width = Int((Double(rectangle.width) / gridSize).rounded(.up) * gridSize)
        let y = Int(Double(GeomUtils.round(Double(rectangle.y) / gridSize)) * gridSize)
        let height = Int((Double(rectangle.height) / gridSize).rounded(.up) * gridSize)
        return Rectangle(x: x, y: y, width: width, height: height)
    }

    /// The point on the grid that is closest to `point`.
    public static func snapped(_ point: Point) -> Point {
        let x = Int(Double(GeomUtils.round(Double(point.x) / gridSize)) * gridSize)
        let y = Int(Double(GeomUtils.round(Double(point.y) / gridSize)) * gridSize)
        return Point(x: x, y: y)
    }

    /// The point with only its x-coordinate snapped to the grid.
    public static func snappedHorizontally(_ point: Point) -> Point {
        let snappedPoint = snapped(point)
        return Point(x: snappedPoint.x, y: point.y)
    }

    /// The point with only its y-coordinate snapped to the grid.
    public static func snappedVertically(_ point: Point) -> Point {
        let snappedPoint = snapped(point)
        return Point(x: point.x, y: snappedPoint.y)
    }

    /// The next integer that lies on the grid, i.e. is a multiple of the grid pitch.
    /// - Precondition: `coordinate >= 0`.
    public static func toMultiple(_ coordinate: Int) -> Int {
        precondition(coordinate >= 0)
        return Int((Double(coordinate) / gridSize).rounded(.up) * gridSize)
    }
}
