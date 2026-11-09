//
//  StoredEdgeRenderer.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.edges.AbstractEdgeRenderer and
//  org.jetuml.rendering.edges.StoredEdgeRenderer
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The original computes `contains`/`getBounds` through JavaFX `Shape` geometry; here
//  paths are polylines, so those two queries are implemented on the polyline
//  (documented approximation: the stroke is assumed to be ~2*MAX_DISTANCE wide).
//

import CoreGraphics
import Foundation
import UMLGeometry
import UMLModel

/// Shared services for rendering edges.
open class AbstractEdgeRenderer: DiagramElementRenderer {

    public static let maxDistance = 3
    public static let buttonSize = 25
    public static let offset = 3
    public static let maxLengthForNormalFont = 15

    static let sizeTester = StringRenderer(.left)
    private static let degrees180 = 180

    private let parentRenderer: any RenderingContextOwner & EdgePathProviding

    public init(_ parent: any RenderingContextOwner & EdgePathProviding) {
        self.parentRenderer = parent
    }

    public var parent: any RenderingContextOwner & EdgePathProviding { parentRenderer }

    /// The default shape: a straight line between the connection points.
    open func shape(of edge: any Edge) -> [PathCommand] {
        let endPoints = connectionPoints(of: edge)
        return [.move(to: endPoints.point1), .line(to: endPoints.point2)]
    }

    /// The width and height of the text.
    class func textDimensions(_ text: String) -> UMLGeometry.Dimension {
        sizeTester.dimension(of: text)
    }

    /// Breaks up a label according to the distance between the two nodes
    /// (port of `AbstractEdgeRenderer.wrapLabel`).
    static func wrapLabel(_ label: String, _ distanceInX: Int, _ distanceInY: Int) -> String {
        let singleCharWidth = sizeTester.dimension(of: " ").width
        let singleCharHeight = sizeTester.dimension(of: " ").height
        var lineLength = maxLengthForNormalFont
        let distanceInXPerChar = singleCharWidth > 0 ? Double(distanceInX) / Double(singleCharWidth) : 0
        let distanceInYPerChar = singleCharHeight > 0 ? Double(distanceInY) / Double(singleCharHeight) : 0
        if distanceInX > 0 && distanceInXPerChar > 0 {
            let angleInDegrees = atan(distanceInYPerChar / distanceInXPerChar) * 180 / Double.pi
            lineLength = max(maxLengthForNormalFont,
                             Int((Double(distanceInX) / 4) * (1 - angleInDegrees / 180)))
        }
        return wrapString(label, lineLength)
    }

    open func contains(_ element: any DiagramElement, _ point: Point) -> Bool {
        guard let edge = element as? any Edge else { return false }
        // Purposefully does not include the arrow head and labels, which create large bounds.
        let connection = connectionPoints(of: edge)
        if point.distance(to: connection.point1) <= Double(Self.maxDistance)
            || point.distance(to: connection.point2) <= Double(Self.maxDistance) {
            return false
        }
        return Self.polylineContains(shape(of: edge), point, tolerance: Self.maxDistance)
    }

    open func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        preconditionFailure("\(type(of: self)) must override draw")
    }

    /// The line style used when the edge is drawn as a palette icon.
    open var iconLineStyle: LineStyle { .solid }

    /// The arrow head at the left end of the icon.
    open var iconArrowStart: ArrowHead { .none }

    /// The arrow head at the right end of the icon.
    open var iconArrowEnd: ArrowHead { .none }

    /// Draws the edge as a diagonal line, as `createIcon` does in the original:
    /// the start decoration points into the line, the end decoration out of it.
    open func drawIconDiagonal(_ element: any DiagramElement, _ context: any RenderingContext) {
        let start = Point(x: IconRendering.offset, y: IconRendering.offset)
        let end = Point(x: IconRendering.buttonSize - IconRendering.offset,
                        y: IconRendering.buttonSize - IconRendering.offset)
        context.strokeLine(start.x, start.y, end.x, end.y,
                           IconStyleSettings.strokeColor, iconLineStyle)
        if iconArrowEnd != .none {
            ArrowHeadRenderer.draw(IconRendering.scaling(context, by: IconRendering.decorationScale,
                                                         around: end),
                                   iconArrowEnd, start, end)
        }
        if iconArrowStart != .none {
            ArrowHeadRenderer.draw(IconRendering.scaling(context, by: IconRendering.decorationScale,
                                                         around: start),
                                   iconArrowStart, end, start)
        }
    }

    /// Draws the edge as a diagonal line, as `createIcon` does in the original.
    open func createIcon(_ element: any DiagramElement) -> CGImage? {
        IconRendering.icon { context in
            self.drawIconDiagonal(element, context)
        }
    }

    open func bounds(_ element: any DiagramElement) -> Rectangle {
        guard let edge = element as? any Edge else {
            preconditionFailure("not an edge")
        }
        return Self.polylineBounds(shape(of: edge))
    }

    /// The connection points of an edge: the points chosen by each node for the
    /// direction towards the other node's centre.
    open func connectionPoints(of edge: any Edge) -> Line {
        guard let start = edge.start(), let end = edge.end() else {
            preconditionFailure("edge is not connected")
        }
        let startBounds = parent.bounds(of: start)
        let endBounds = parent.bounds(of: end)
        let toEnd = Direction.fromLine(startBounds.center(), endBounds.center())
        return Line(point1: parent.connectionPoint(of: start, toEnd),
                    point2: parent.connectionPoint(of: end, toEnd.rotatedBy(Self.degrees180)))
    }

    /// Breaks up the string so that each line has at most `lineLength` characters.
    static func wrapString(_ string: String, _ lineLength: Int) -> String {
        var remainingEmptySpace = lineLength
        let spaceLength = 1
        let words = string.components(separatedBy: " ")
        var formatted = ""
        for word in words {
            if word.count > remainingEmptySpace && !formatted.isEmpty {
                // Replace the last space with a newline.
                formatted.removeLast()
                formatted.append("\n")
                remainingEmptySpace = lineLength
            }
            remainingEmptySpace = remainingEmptySpace - word.count - spaceLength
            formatted.append(word)
            formatted.append(" ")
        }
        if !formatted.isEmpty {
            formatted.removeLast()
        }
        return formatted
    }

    // MARK: - Polyline helpers

    /// True if the point is within `tolerance` of any segment of the path.
    static func polylineContains(_ path: [PathCommand], _ point: Point, tolerance: Int) -> Bool {
        let points = path.map(Self.endPoint)
        guard points.count >= 2 else { return false }
        for index in 0..<(points.count - 1) {
            if distanceToSegment(point, points[index], points[index + 1]) <= Double(tolerance) {
                return true
            }
        }
        return false
    }

    /// The bounding box of the path's points.
    static func polylineBounds(_ path: [PathCommand]) -> Rectangle {
        let points = path.map(Self.endPoint)
        guard !points.isEmpty else {
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }
        return Rectangle.spanning(points)
    }

    /// The endpoint of a path command.
    static func endPoint(_ command: PathCommand) -> Point {
        switch command {
        case let .move(point), let .line(point): point
        case let .quadCurve(_, point): point
        }
    }

    /// The distance between a point and a segment.
    static func distanceToSegment(_ point: Point, _ start: Point, _ end: Point) -> Double {
        let dx = Double(end.x - start.x)
        let dy = Double(end.y - start.y)
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return point.distance(to: start)
        }
        let projection = (Double(point.x - start.x) * dx + Double(point.y - start.y) * dy) / lengthSquared
        let clamped = min(max(projection, 0), 1)
        let closest = Point(x: GeomUtils.round(Double(start.x) + clamped * dx),
                            y: GeomUtils.round(Double(start.y) + clamped * dy))
        return point.distance(to: closest)
    }
}

/// Can draw an edge as a straight line between the connection points of the start and
/// end nodes that are closest to each other, with a configurable line style and end
/// arrow head (port of `StraightEdgeRenderer`).
open class StraightEdgeRenderer: AbstractEdgeRenderer {

    public let straightLineStyle: LineStyle
    public let straightArrowHead: ArrowHead

    public init(_ parent: any RenderingContextOwner & EdgePathProviding,
                _ lineStyle: LineStyle, _ arrowHead: ArrowHead) {
        self.straightLineStyle = lineStyle
        self.straightArrowHead = arrowHead
        super.init(parent)
    }

    public override var iconLineStyle: LineStyle { straightLineStyle }

    public override var iconArrowEnd: ArrowHead { straightArrowHead }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let edge = element as? any Edge else {
            preconditionFailure("not an edge")
        }
        context.strokePath(shape(of: edge), color: ColorScheme.current.strokeColor, style: straightLineStyle)
        ArrowHeadRenderer.draw(context, straightArrowHead, connectionPoints(of: edge))
    }

    public override func bounds(_ element: any DiagramElement) -> Rectangle {
        var bounds = super.bounds(element)
        guard let edge = element as? any Edge else {
            return bounds
        }
        if straightArrowHead != .none {
            bounds = bounds.add(ArrowHeadRenderer.bounds(straightArrowHead, connectionPoints(of: edge)))
        }
        return bounds
    }
}

/// A straight dotted line, used to connect notes (port of `NoteEdgeRenderer`).
public final class NoteEdgeRenderer: StraightEdgeRenderer {

    public init(_ parent: any RenderingContextOwner & EdgePathProviding) {
        super.init(parent, .dotted, .none)
    }
}

/// Supplies the planned path of an edge (implemented by the diagram renderer).
public protocol EdgePathProviding: AnyObject {
    func storedEdgePath(_ edge: any Edge) -> EdgePath?
}

/// Renders the stored path of a class-diagram edge.
public final class StoredEdgeRenderer: AbstractEdgeRenderer {

    /// Class-diagram edges use their own line style and decorations in the palette icon.
    public override var iconLineStyle: LineStyle { .solid }

    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        guard let edge = element as? any Edge else { return nil }
        let lineStyle = Self.lineStyle(edge)
        let arrowStart = Self.arrowStart(edge)
        let arrowEnd = Self.arrowEnd(edge)
        let start = Point(x: IconRendering.offset, y: IconRendering.offset)
        let end = Point(x: IconRendering.buttonSize - IconRendering.offset,
                        y: IconRendering.buttonSize - IconRendering.offset)
        return IconRendering.icon { context in
            context.strokeLine(start.x, start.y, end.x, end.y,
                               IconStyleSettings.strokeColor, lineStyle)
            if arrowEnd != .none {
                ArrowHeadRenderer.draw(IconRendering.scaling(context,
                                                             by: IconRendering.decorationScale,
                                                             around: end),
                                       arrowEnd, start, end)
            }
            if arrowStart != .none {
                ArrowHeadRenderer.draw(IconRendering.scaling(context,
                                                             by: IconRendering.decorationScale,
                                                             around: start),
                                       arrowStart, end, start)
            }
        }
    }

    private static let topCenteredStringViewer = StringRenderer(.center)
    private static let bottomCenteredStringViewer = StringRenderer(.center)
    private static let leftJustifiedStringViewer = StringRenderer(.left)
    private static let degrees180 = 180

    /// The line style for an edge.
    static func lineStyle(_ edge: any Edge) -> LineStyle {
        let priority = EdgePriority.priority(of: edge)
        return priority == .implementation || priority == .dependency ? .dotted : .solid
    }

    /// The arrow head at the start of an edge.
    static func arrowStart(_ edge: any Edge) -> ArrowHead {
        if let edge = edge as? AggregationEdge {
            return edge.type == .composition ? .blackDiamond : .diamond
        } else if let edge = edge as? AssociationEdge {
            if edge.directionality == .bidirectional {
                return .v
            }
        } else if let edge = edge as? DependencyEdge {
            if edge.directionality == .bidirectional {
                return .v
            }
        }
        return .none
    }

    /// The arrow head at the end of an edge.
    static func arrowEnd(_ edge: any Edge) -> ArrowHead {
        if edge is GeneralizationEdge {
            return .triangle
        } else if edge is AggregationEdge {
            return .none
        } else if edge is DependencyEdge {
            return .v
        } else if let edge = edge as? AssociationEdge {
            if edge.directionality == .unidirectional || edge.directionality == .bidirectional {
                return .v
            }
        }
        return .none
    }

    /// The path of the edge's stored trajectory.
    func segmentPath(_ edge: any Edge) -> [PathCommand] {
        let path = storedPath(edge)
        var commands: [PathCommand] = [.move(to: path.startPoint)]
        for index in 1..<path.size {
            commands.append(.line(to: path.point(at: index)))
        }
        return commands
    }

    /// True if the edge steps up (goes up while moving right, or down while moving left).
    func isStepUp(_ edge: any Edge) -> Bool {
        let path = storedPath(edge)
        let point1 = path.startPoint
        let point2 = path.endPoint
        return (point1.x < point2.x && point1.y > point2.y) || (point1.x > point2.x && point1.y < point2.y)
    }

    public override func shape(of edge: any Edge) -> [PathCommand] {
        segmentPath(edge)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let edge = element as? any Edge else {
            preconditionFailure("not an edge")
        }
        let path = storedPath(edge)
        context.strokePath(segmentPath(edge), color: ColorScheme.current.strokeColor, style: Self.lineStyle(edge))
        ArrowHeadRenderer.draw(context, Self.arrowStart(edge), path.point(at: 1), path.startPoint)
        ArrowHeadRenderer.draw(context, Self.arrowEnd(edge), path.point(at: path.size - 2), path.endPoint)

        drawLabel(context, Self.segmentForStartLabel(path), Self.arrowStart(edge),
                  Self.startLabel(edge), centered: false, stepUp: isStepUp(edge))
        drawLabel(context, Self.segmentForMiddleLabel(path), .none,
                  Self.middleLabel(edge), centered: true, stepUp: isStepUp(edge))
        drawLabel(context, Self.segmentForEndLabel(path), Self.arrowEnd(edge),
                  Self.endLabel(edge), centered: false, stepUp: isStepUp(edge))
    }

    public override func bounds(_ element: any DiagramElement) -> Rectangle {
        guard let edge = element as? any Edge else {
            preconditionFailure("not an edge")
        }
        let path = storedPath(edge)
        var bounds = super.bounds(edge)
        bounds = bounds.add(Self.labelBounds(Self.segmentForStartLabel(path), Self.arrowStart(edge),
                                             Self.startLabel(edge), centered: false, stepUp: isStepUp(edge)))
        bounds = bounds.add(Self.labelBounds(Self.segmentForMiddleLabel(path), .none,
                                             Self.middleLabel(edge), centered: true, stepUp: isStepUp(edge)))
        bounds = bounds.add(Self.labelBounds(Self.segmentForEndLabel(path), Self.arrowEnd(edge),
                                             Self.endLabel(edge), centered: false, stepUp: isStepUp(edge)))
        return bounds
    }

    public override func contains(_ element: any DiagramElement, _ point: Point) -> Bool {
        guard let edge = element as? any Edge, let path = parent.storedEdgePath(edge) else {
            return false
        }
        // As in the original, the search radius includes the connection points here.
        if point.distance(to: path.startPoint) <= Double(Self.maxDistance)
            || point.distance(to: path.endPoint) <= Double(Self.maxDistance) {
            return true
        }
        return Self.polylineContains(segmentPath(edge), point, tolerance: Self.maxDistance)
    }

    public override func connectionPoints(of edge: any Edge) -> Line {
        let path = storedPath(edge)
        return Line(point1: path.startPoint, point2: path.endPoint)
    }

    // MARK: - Labels

    private func drawLabel(_ context: any RenderingContext, _ segment: Line, _ arrowHead: ArrowHead,
                           _ string: String, centered: Bool, stepUp: Bool) {
        guard !string.isEmpty else {
            return
        }
        let label = Self.wrapLabel(string, segment)
        let bounds = Self.labelBounds(segment, arrowHead, label, centered: centered, stepUp: stepUp)
        if centered {
            if segment.y2 >= segment.y1 {
                Self.topCenteredStringViewer.draw(label, in: bounds, with: context)
            } else {
                Self.bottomCenteredStringViewer.draw(label, in: bounds, with: context)
            }
        } else {
            Self.leftJustifiedStringViewer.draw(label, in: bounds, with: context)
        }
    }

    static func wrapLabel(_ label: String, _ segment: Line) -> String {
        let distances = segment.distanceBetweenPoints()
        let singleCharWidth = leftJustifiedStringViewer.dimension(of: " ").width
        let singleCharHeight = leftJustifiedStringViewer.dimension(of: " ").height
        var lineLength = maxLengthForNormalFont
        let distanceInXPerChar = singleCharWidth > 0 ? Double(distances.width) / Double(singleCharWidth) : 0
        let distanceInYPerChar = singleCharHeight > 0 ? Double(distances.height) / Double(singleCharHeight) : 0
        if distances.width > 0 {
            let angleInDegrees = atan(distanceInYPerChar / distanceInXPerChar) * 180 / Double.pi
            lineLength = max(maxLengthForNormalFont,
                             Int((Double(distances.width) / 4) * (1 - angleInDegrees / Double(degrees180))))
        }
        return wrapString(label, lineLength)
    }

    static func labelBounds(_ segment: Line, _ arrowHead: ArrowHead, _ label: String,
                            centered: Bool, stepUp: Bool) -> Rectangle {
        guard !label.isEmpty else {
            return Rectangle(x: segment.x2, y: segment.y2, width: 0, height: 0)
        }
        let textDimensions = topCenteredStringViewer.dimension(of: label)
        let attachmentPoint = self.attachmentPoint(segment, arrowHead, textDimensions, centered: centered,
                                                   stepUp: stepUp)
        return Rectangle(x: attachmentPoint.x, y: attachmentPoint.y,
                         width: textDimensions.width, height: textDimensions.height)
    }

    /// Computes the attachment point for drawing a label.
    static func attachmentPoint(_ segment: Line, _ arrowHead: ArrowHead, _ dimension: UMLGeometry.Dimension,
                                centered: Bool, stepUp: Bool) -> Point {
        let gap = 3
        var xoff = Double(gap)
        var yoff = Double(-gap - dimension.height)
        var attach = segment.point2
        if centered {
            if segment.x1 > segment.x2 {
                return attachmentPoint(segment.reversed(), arrowHead, dimension, centered: centered, stepUp: stepUp)
            }
            attach = segment.center()
            if segment.isVertical && stepUp {
                yoff = Double(gap)
            } else if segment.isVertical && !stepUp {
                yoff = Double(-gap - dimension.height)
            } else if segment.isHorizontal {
                if dimension.width > segment.distanceBetweenPoints().width {
                    attach = Point(x: segment.x2 + (dimension.width / 2) + gap,
                                   y: (segment.y1 + segment.y2) / 2)
                }
                xoff = Double(-dimension.width / 2)
            }
        } else {
            if segment.x1 < segment.x2 {
                xoff = Double(-gap - dimension.width)
            }
            if segment.y1 > segment.y2 {
                yoff = Double(gap)
            }
            if arrowHead != .none {
                let arrowBounds = ArrowHeadRenderer.bounds(arrowHead, segment)
                if segment.isHorizontal {
                    yoff -= Double(arrowBounds.height / 2)
                } else if segment.isVertical {
                    xoff += Double(arrowBounds.width / 2)
                }
            }
        }
        return Point(x: Int(Double(attach.x) + xoff), y: Int(Double(attach.y) + yoff))
    }

    static func startLabel(_ edge: any Edge) -> String {
        (edge as? ThreeLabelEdge)?.startLabel ?? ""
    }

    static func middleLabel(_ edge: any Edge) -> String {
        if let edge = edge as? ThreeLabelEdge {
            return edge.middleLabel
        }
        if let edge = edge as? SingleLabelEdge {
            return edge.middleLabel
        }
        return ""
    }

    static func endLabel(_ edge: any Edge) -> String {
        (edge as? ThreeLabelEdge)?.endLabel ?? ""
    }

    static func segmentForStartLabel(_ path: EdgePath) -> Line {
        Line(point1: path.point(at: 1), point2: path.startPoint)
    }

    static func segmentForMiddleLabel(_ path: EdgePath) -> Line {
        // If any point is the same we consider this a straight path.
        if path.size == 4 && (path.point(at: 0) == path.point(at: 1)
            || path.point(at: 1) == path.point(at: 2)
            || path.point(at: 2) == path.point(at: 3)) {
            return Line(point1: path.startPoint, point2: path.endPoint)
        }
        return Line(point1: path.point(at: path.size / 2 - 1), point2: path.point(at: path.size / 2))
    }

    static func segmentForEndLabel(_ path: EdgePath) -> Line {
        Line(point1: path.point(at: path.size - 2), point2: path.point(at: path.size - 1))
    }

    private func storedPath(_ edge: any Edge) -> EdgePath {
        guard let path = parent.storedEdgePath(edge) else {
            preconditionFailure("edge has no stored path: \(edge)")
        }
        return path
    }
}
