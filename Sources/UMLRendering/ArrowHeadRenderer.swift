//
//  ArrowHead.swift, ArrowHeadRenderer.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.ArrowHead and
//  org.jetuml.rendering.edges.ArrowHeadRenderer
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import Foundation
import UMLGeometry
import UMLModel

/// The arrow heads of various shapes.
public enum ArrowHead: Sendable {
    case none
    case triangle
    case blackTriangle
    case v
    case halfV
    case diamond
    case blackDiamond

    /// True iff this arrow head is in the shape of a triangle.
    public var isTriangle: Bool { self == .triangle || self == .blackTriangle }

    /// True iff this arrow head is in the shape of a diamond.
    public var isDiamond: Bool { self == .diamond || self == .blackDiamond }

    /// True iff this arrow head is filled with a solid colour.
    public var isFilled: Bool { self == .blackTriangle || self == .blackDiamond }
}

/// Computes the geometry of arrow heads and renders them.
public enum ArrowHeadRenderer {

    private static let arrowAngle = Double.pi / 6
    private static let arrowLength = 10.0

    /// Draws an arrow head at the end of `axis`, pointing to `axis.point2`.
    public static func draw(_ context: any RenderingContext, _ arrowHead: ArrowHead, _ axis: Line) {
        let path = Self.path(arrowHead, axis)
        if path.isEmpty {
            return
        }
        if arrowHead.isFilled {
            context.drawClosedPath(path, fill: RGBAColor.black,
                                   stroke: ColorScheme.current.strokeColor, hasShadow: false)
        } else {
            context.drawClosedPath(path, fill: RGBAColor.white,
                                   stroke: ColorScheme.current.strokeColor, hasShadow: false)
        }
    }

    /// Draws an arrow head at `point2` for a direction given from `point1`.
    public static func draw(_ context: any RenderingContext, _ arrowHead: ArrowHead,
                            _ point1: Point, _ point2: Point) {
        draw(context, arrowHead, Line(point1: point1, point2: point2))
    }

    /// The bounds of an arrow head pointing to the second point of the axis.
    public static func bounds(_ arrowHead: ArrowHead, _ axis: Line) -> Rectangle {
        let points = Self.path(arrowHead, axis).map(Self.point)
        return Rectangle.spanning(points)
    }

    /// The path of the arrow head.
    static func path(_ arrowHead: ArrowHead, _ axis: Line) -> [PathCommand] {
        if arrowHead == .none {
            return []
        }
        let dx = axis.x2 - axis.x1
        let dy = axis.y2 - axis.y1
        let angle = atan2(Double(dy), Double(dx))
        let x1 = GeomUtils.round(Double(axis.x2) - Self.arrowLength * cos(angle + Self.arrowAngle))
        let y1 = GeomUtils.round(Double(axis.y2) - Self.arrowLength * sin(angle + Self.arrowAngle))
        let x2 = GeomUtils.round(Double(axis.x2) - Self.arrowLength * cos(angle - Self.arrowAngle))
        let y2 = GeomUtils.round(Double(axis.y2) - Self.arrowLength * sin(angle - Self.arrowAngle))

        var path: [PathCommand] = [.move(to: Point(x: axis.x2, y: axis.y2)), .line(to: Point(x: x1, y: y1))]
        if arrowHead == .v {
            path.append(.move(to: Point(x: x2, y: y2)))
            path.append(.line(to: Point(x: axis.x2, y: axis.y2)))
        } else if arrowHead.isTriangle {
            path.append(.line(to: Point(x: x2, y: y2)))
            path.append(.line(to: Point(x: axis.x2, y: axis.y2)))
        } else if arrowHead.isDiamond {
            let x3 = GeomUtils.round(Double(x2) - Self.arrowLength * cos(angle + Self.arrowAngle))
            let y3 = GeomUtils.round(Double(y2) - Self.arrowLength * sin(angle + Self.arrowAngle))
            path.append(.line(to: Point(x: x3, y: y3)))
            path.append(.line(to: Point(x: x2, y: y2)))
            path.append(.line(to: Point(x: axis.x2, y: axis.y2)))
        }
        return path
    }

    private static func point(_ command: PathCommand) -> Point {
        switch command {
        case let .move(point), let .line(point): point
        case let .quadCurve(_, point): point
        }
    }
}
