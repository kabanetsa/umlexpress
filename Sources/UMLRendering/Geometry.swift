//
//  Side.swift, NodeIndex.swift, NodeCorner.swift, EdgePriority.swift, EdgePath.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.Side, org.jetuml.rendering.edges.NodeIndex,
//  org.jetuml.rendering.NodeCorner, org.jetuml.rendering.EdgePriority and
//  org.jetuml.rendering.EdgePath (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry
import UMLModel

/// One side of a rectangular node.
public enum Side: CaseIterable, Sendable {
    case top
    case bottom
    case right
    case left

    /// True if this side is a horizontal line (top or bottom).
    public var isHorizontal: Bool { self == .top || self == .bottom }

    /// True if this side is a vertical line (right or left).
    public var isVertical: Bool { self == .right || self == .left }

    /// The side opposite this side.
    public func mirrored() -> Side {
        switch self {
        case .top: .bottom
        case .bottom: .top
        case .right: .left
        case .left: .right
        }
    }

    /// The line that corresponds to this side of the given rectangle.
    public func line(in rectangle: Rectangle) -> Line {
        switch self {
        case .top:
            Line(point1: Point(x: rectangle.x, y: rectangle.y),
                 point2: Point(x: rectangle.maxX, y: rectangle.y))
        case .bottom:
            Line(point1: Point(x: rectangle.x, y: rectangle.maxY),
                 point2: Point(x: rectangle.maxX, y: rectangle.maxY))
        case .right:
            Line(point1: Point(x: rectangle.maxX, y: rectangle.y),
                 point2: Point(x: rectangle.maxX, y: rectangle.maxY))
        case .left:
            Line(point1: Point(x: rectangle.x, y: rectangle.y),
                 point2: Point(x: rectangle.x, y: rectangle.maxY))
        }
    }
}

/// Indexed positions on the faces of nodes where edges can attach.
///
/// North- and South-facing sides have indices in `-4...+4`; East- and West-facing sides
/// have indices in `-2...+2`.
public enum NodeIndex: Int, CaseIterable, Sendable {
    case minusFour = -4
    case minusThree = -3
    case minusTwo = -2
    case minusOne = -1
    case zero = 0
    case plusOne = 1
    case plusTwo = 2
    case plusThree = 3
    case plusFour = 4

    /// Number of attachment spaces for north and south sides.
    private static let numSpacesNS = 9
    /// Number of attachment spaces for east and west sides.
    private static let numSpacesEW = 5
    /// Space between attachment points are increments of this number.
    private static let spaceIncrement = 10
    /// Extra margin at the end of the face so that the layout looks concentrated in the
    /// middle; purely aesthetic, as in the original.
    private static let margin = 10

    /// The point on `face` at the position represented by this index.
    public func point(on face: Line, side: Side) -> Point {
        let spacing = NodeIndex.spaceBetweenConnectionPoints(face, side)
        let offset = rawValue * spacing
        if side.isHorizontal {
            let center = GridUtils.snappedHorizontally(
                Point(x: ((face.x2 - face.x1) / 2) + face.x1, y: face.y1))
            return Point(x: center.x + offset, y: center.y)
        } else {
            let center = GridUtils.snappedVertically(
                Point(x: face.x1, y: ((face.y2 - face.y1) / 2) + face.y1))
            return Point(x: center.x, y: center.y + offset)
        }
    }

    /// The number of pixels between edge connection points on a face: at least 10, then
    /// any greater multiple of 10 if possible.
    private static func spaceBetweenConnectionPoints(_ face: Line, _ side: Side) -> Int {
        var lengthOfSide = abs(face.x2 - face.x1)
        var numberOfSpaces = numSpacesNS
        if side.isVertical {
            lengthOfSide = abs(face.y2 - face.y1)
            numberOfSpaces = numSpacesEW
        }
        let unadjustedSpace = GeomUtils.round(
            Double(lengthOfSide - margin * 2) / Double(numberOfSpaces))
        // Closest further multiple of 10, at least 10.
        return max(spaceIncrement, unadjustedSpace / spaceIncrement * spaceIncrement)
    }
}

/// The four corners of a node, used to plan the placement of self-edges.
public enum NodeCorner: CaseIterable, Sendable {
    case topRight
    case topLeft
    case bottomLeft
    case bottomRight

    /// The horizontal (north or south) index associated with a corner: +3 for a right
    /// corner, -3 otherwise.
    public static func horizontalIndex(_ corner: NodeCorner) -> NodeIndex {
        corner == .bottomRight || corner == .topRight ? .plusThree : .minusThree
    }

    /// The vertical (east or west) index associated with a corner: -1 for a top corner,
    /// +1 otherwise.
    public static func verticalIndex(_ corner: NodeCorner) -> NodeIndex {
        corner == .topLeft || corner == .topRight ? .minusOne : .plusOne
    }

    /// The direction (north or south) describing a corner's horizontal position.
    public static func horizontalSide(_ corner: NodeCorner) -> Direction {
        corner == .topRight || corner == .topLeft ? Direction.north : Direction.south
    }

    /// The direction (east or west) describing a corner's vertical position.
    public static func verticalSide(_ corner: NodeCorner) -> Direction {
        corner == .topRight || corner == .bottomRight ? Direction.east : Direction.west
    }
}

/// Priority levels for edges, so that edges are laid out in a hierarchical order.
/// Declared in decreasing order of priority (inheritance is the highest).
public enum EdgePriority: CaseIterable, Sendable {
    case inheritance
    case implementation
    case aggregation
    case composition
    case association
    case dependency
    case selfEdge
    case other

    /// The priority of an edge.
    public static func priority(of edge: any Edge) -> EdgePriority {
        if let start = edge.start(), let end = edge.end(), start === end {
            return .selfEdge
        } else if let edge = edge as? GeneralizationEdge {
            return edge.type == .inheritance ? .inheritance : .implementation
        } else if let edge = edge as? AggregationEdge {
            return edge.type == .aggregation ? .aggregation : .composition
        } else if edge is AssociationEdge {
            return .association
        } else if edge is DependencyEdge {
            return .dependency
        } else {
            return .other
        }
    }

    /// True if this priority describes a segmented edge. Self-edges are planned
    /// separately and are not segmented by this predicate.
    public static func isSegmented(_ priority: EdgePriority) -> Bool {
        switch priority {
        case .inheritance, .implementation, .aggregation, .composition, .association: true
        case .dependency, .selfEdge, .other: false
        }
    }

    /// True if the edge is segmented.
    public static func isSegmentedEdge(_ edge: any Edge) -> Bool {
        isSegmented(priority(of: edge))
    }

    /// True if the edge is a class-diagram edge that can be stored in `EdgeStorage`.
    public static func isStoredEdge(_ edge: any Edge) -> Bool {
        priority(of: edge) != .other
    }
}

/// The path of an edge on a diagram, as a list of points.
///
/// Non-segmented paths consist of 2 points (the start and end points).
public struct EdgePath: Equatable, Sendable {

    private var points: [Point]

    /// Creates a path from the given points.
    /// - Precondition: at least two points.
    public init(_ points: Point...) {
        precondition(points.count >= 2)
        self.points = points
    }

    public init(points: [Point]) {
        precondition(points.count >= 2)
        self.points = points
    }

    /// The point where the edge starts.
    public var startPoint: Point { points[0] }

    /// The point where the edge ends.
    public var endPoint: Point { points[points.count - 1] }

    /// The point at `index`, where 0 is the start point.
    public func point(at index: Int) -> Point {
        precondition(index >= 0 && index < points.count)
        return points[index]
    }

    /// The number of points in the path.
    public var size: Int { points.count }

    /// The points of the path.
    public var allPoints: [Point] { points }
}

extension EdgePath: Sequence {
    public func makeIterator() -> IndexingIterator<[Point]> {
        points.makeIterator()
    }
}
