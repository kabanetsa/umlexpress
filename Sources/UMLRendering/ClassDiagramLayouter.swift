//
//  ClassDiagramLayouter.swift
//  UMLExpress
//
//  Port of the edge-routing algorithm of org.jetuml.rendering.ClassDiagramRenderer
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The original class mixes drawing and layout. This port keeps only the layout part:
//  the plan (§M1.5) calls for isolating the 1300-line heuristic so that it can be
//  validated independently of the drawing pipeline. Node geometry comes from a
//  `NodeBoundsProvider`, which in the full renderer is backed by node renderers
//  (text metrics), and in tests by fixed rectangles.
//

import UMLGeometry
import UMLModel

/// Supplies the bounding box of a node, standing in for `NodeRenderer.getBounds(node)`.
public protocol NodeBoundsProvider {
    func bounds(of node: any Node) -> Rectangle
}

extension NodeBoundsProvider {
    /// The line describing one face of a node, as `AbstractNodeRenderer.getFace`.
    public func face(of node: any Node, _ side: Side) -> Line {
        side.line(in: bounds(of: node))
    }
}

/// Plans and stores the `EdgePath` of every edge of a class diagram.
public final class ClassDiagramLayouter {

    private static let twentyPixels = 20
    private static let tenPixels = 10

    private let diagram: Diagram
    private let bounds: NodeBoundsProvider

    /// The planned paths, by edge identity.
    public let storage: EdgeStorage

    public init(diagram: Diagram, bounds: NodeBoundsProvider, storage: EdgeStorage = EdgeStorage()) {
        self.diagram = diagram
        self.bounds = bounds
        self.storage = storage
    }

    // MARK: - Layout

    /// Plans and stores the `EdgePath` of every edge in the diagram.
    public func layout() {
        storage.clear()
        for priority in [EdgePriority.inheritance, .implementation, .aggregation, .composition, .association] {
            layoutSegmentedEdges(priority)
        }
        layoutDependencyEdges()
        layoutSelfEdges()
    }

    /// The stored path for an edge, if it has one.
    public func storedEdgePath(_ edge: any Edge) -> EdgePath? {
        storage.contains(edge) ? storage.edgePath(edge) : nil
    }

    /// Plans the paths of all segmented edges with the given priority, merging edges
    /// that share a connection point.
    private func layoutSegmentedEdges(_ priority: EdgePriority) {
        precondition(EdgePriority.isSegmented(priority))
        // Java's stream sort is stable; sort by (x of start node position, original order).
        var edgesToProcess = diagram.edges
            .enumerated()
            .filter { EdgePriority.priority(of: $0.element) == priority }
            .sorted { lhs, rhs in
                let x1 = lhs.element.start()?.position.x ?? 0
                let x2 = rhs.element.start()?.position.x ?? 0
                return x1 == x2 ? lhs.offset < rhs.offset : x1 < x2
            }
            .map(\.element)

        while !edgesToProcess.isEmpty {
            let currentEdge = edgesToProcess[0]
            guard let currentStart = currentEdge.start() else {
                edgesToProcess.removeFirst()
                continue
            }
            let edgeDirection = attachedSide(currentEdge, currentStart)
            var edgesToMergeStart = edgesToMergeStart(currentEdge, edgesToProcess)
            var edgesToMergeEnd = edgesToMergeEnd(currentEdge, edgesToProcess)

            if !edgesToMergeStart.isEmpty {
                edgesToMergeStart.append(currentEdge)
                removeAll(&edgesToProcess, edgesToMergeStart)
                storeMergedStartEdges(edgeDirection, edgesToMergeStart)
            } else {
                edgesToMergeEnd.append(currentEdge)
                removeAll(&edgesToProcess, edgesToMergeEnd)
                storeMergedEndEdges(edgeDirection, edgesToMergeEnd)
            }
        }
    }

    /// Plans the paths of dependency edges: a single straight segment.
    private func layoutDependencyEdges() {
        for edge in diagram.edges where EdgePriority.priority(of: edge) == .dependency {
            guard let start = edge.start(), let end = edge.end() else { continue }
            let attachedEndSide = attachedSide(edge, end)
            let startPoint = connectionPoint(start, edge, attachedEndSide.mirrored())
            let endPoint = connectionPoint(end, edge, attachedEndSide)
            storage.store(edge, EdgePath(startPoint, endPoint))
        }
    }

    /// Plans the paths of self-edges.
    private func layoutSelfEdges() {
        let selfEdges = diagram.edges.filter { EdgePriority.priority(of: $0) == .selfEdge }
        for edge in selfEdges {
            let corner = selfEdgeCorner(edge)
            storage.store(edge, buildSelfEdge(edge, corner))
        }
    }

    /// The first corner (from `topRight`, counter-clockwise) whose connection points are
    /// still available; `topRight` if none are.
    private func selfEdgeCorner(_ edge: any Edge) -> NodeCorner {
        guard let node = edge.end() else {
            return .topRight
        }
        for corner in NodeCorner.allCases {
            let points = toPoints(corner, node)
            if storage.connectionPointIsAvailable(points.start)
                && storage.connectionPointIsAvailable(points.end) {
                return corner
            }
        }
        return .topRight
    }

    /// Builds the 5-point path of a self-edge at the given corner.
    private func buildSelfEdge(_ edge: any Edge, _ corner: NodeCorner) -> EdgePath {
        guard let node = edge.end() else {
            preconditionFailure("self-edge without end node")
        }
        let connectionPoints = toPoints(corner, node)
        let startPoint = connectionPoints.start
        let endPoint = connectionPoints.end

        let firstBend: Point
        if NodeCorner.horizontalSide(corner) == Direction.north {
            firstBend = Point(x: startPoint.x, y: startPoint.y - (2 * Self.tenPixels))
        } else {
            firstBend = Point(x: startPoint.x, y: startPoint.y + (2 * Self.tenPixels))
        }

        let middleBend: Point
        let lastBend: Point
        if NodeCorner.verticalSide(corner) == Direction.east {
            middleBend = Point(x: firstBend.x + (4 * Self.tenPixels), y: firstBend.y)
            lastBend = Point(x: endPoint.x + (2 * Self.tenPixels), y: endPoint.y)
        } else {
            middleBend = Point(x: firstBend.x - (4 * Self.tenPixels), y: firstBend.y)
            lastBend = Point(x: endPoint.x - (2 * Self.tenPixels), y: endPoint.y)
        }
        return EdgePath(startPoint, firstBend, middleBend, lastBend, endPoint)
    }

    /// Stores the paths of edges that merge at a common end point.
    private func storeMergedEndEdges(_ direction: Side, _ edges: [any Edge]) {
        precondition(!edges.isEmpty)
        guard let firstEdge = edges.first, let firstEnd = firstEdge.end() else { return }
        let sharedEndPoint = connectionPoint(firstEnd, firstEdge, direction.mirrored())

        var startPoints: [(edge: any Edge, point: Point)] = []
        for edge in edges {
            guard let start = edge.start() else { continue }
            startPoints.append((edge, connectionPoint(start, edge, direction)))
        }

        let closestStartPoint = Self.closestPoint(startPoints.map(\.point), direction)
        let midLine: Int
        if direction.isHorizontal {
            midLine = horizontalMidLine(closestStartPoint, sharedEndPoint, direction, firstEdge)
        } else {
            midLine = verticalMidLine(closestStartPoint, sharedEndPoint, direction, firstEdge)
        }

        for entry in startPoints {
            storage.store(entry.edge, Self.buildSegmentedEdgePath(direction, entry.point, midLine, sharedEndPoint))
        }
    }

    /// Stores the paths of edges that merge at a common start point.
    private func storeMergedStartEdges(_ direction: Side, _ edges: [any Edge]) {
        precondition(!edges.isEmpty)
        guard let firstEdge = edges.first, let firstStart = firstEdge.start() else { return }
        let startPoint = connectionPoint(firstStart, firstEdge, direction)

        var endPoints: [(edge: any Edge, point: Point)] = []
        for edge in edges {
            guard let end = edge.end() else { continue }
            endPoints.append((edge, connectionPoint(end, edge, direction.mirrored())))
        }

        let closestEndPoint = Self.closestPoint(endPoints.map(\.point), direction.mirrored())
        let midLine: Int
        if direction.isHorizontal {
            midLine = horizontalMidLine(closestEndPoint, startPoint, direction, firstEdge)
        } else {
            midLine = verticalMidLine(closestEndPoint, startPoint, direction, firstEdge)
        }

        for entry in endPoints {
            storage.store(entry.edge, Self.buildSegmentedEdgePath(direction, startPoint, midLine, entry.point))
        }
    }

    /// A 4-point path: start, two middle points on the middle line, end.
    private static func buildSegmentedEdgePath(
        _ direction: Side, _ start: Point, _ midLine: Int, _ end: Point
    ) -> EdgePath {
        precondition(midLine >= 0)
        let firstMiddlePoint: Point
        let secondMiddlePoint: Point
        if direction.isHorizontal {
            firstMiddlePoint = Point(x: start.x, y: midLine)
            secondMiddlePoint = Point(x: end.x, y: midLine)
        } else {
            firstMiddlePoint = Point(x: midLine, y: start.y)
            secondMiddlePoint = Point(x: midLine, y: end.y)
        }
        return EdgePath(start, firstMiddlePoint, secondMiddlePoint, end)
    }

    // MARK: - Merging candidates

    /// The edges that should share an end point with `edge`.
    private func edgesToMergeEnd(_ edge: any Edge, _ candidates: [any Edge]) -> [any Edge] {
        guard let edgeEnd = edge.end() else { return [] }
        return candidates.filter { other in
            guard let otherEnd = other.end(), otherEnd === edgeEnd else { return false }
            guard EdgePriority.priority(of: other) == EdgePriority.priority(of: edge) else { return false }
            guard attachedSide(other, otherEnd) == attachedSide(edge, edgeEnd) else { return false }
            guard Self.noConflictingEndLabels(other, edge) else { return false }
            guard noOtherEdgesBetween(other, edge, edgeEnd) else { return false }
            return !(other === edge)
        }
    }

    /// The edges that should share a start point with `edge`.
    private func edgesToMergeStart(_ edge: any Edge, _ candidates: [any Edge]) -> [any Edge] {
        guard let edgeStart = edge.start() else { return [] }
        return candidates.filter { other in
            guard let otherStart = other.start(), otherStart === edgeStart else { return false }
            guard EdgePriority.priority(of: other) == EdgePriority.priority(of: edge) else { return false }
            guard attachedSide(other, otherStart) == attachedSide(edge, edgeStart) else { return false }
            guard noOtherEdgesBetween(other, edge, edgeStart) else { return false }
            guard Self.noConflictingStartLabels(other, edge) else { return false }
            return !(other === edge)
        }
    }

    // MARK: - Middle lines

    /// The y-coordinate of the horizontal middle segment of `edge`.
    private func horizontalMidLine(
        _ start: Point, _ end: Point, _ direction: Side, _ edge: any Edge
    ) -> Int {
        precondition(direction.isHorizontal)
        precondition(EdgePriority.isSegmentedEdge(edge))
        let sharedNodeEdges = storage.edgesWithSameNodes(edge)
        if let first = sharedNodeEdges.first {
            return horizontalMidlineForSharedNodeEdges(first, edge, direction)
        }
        if let closest = closestConflictingHorizontalSegment(direction, edge) {
            return adjacentHorizontalMidLine(closest, edge, direction)
        }
        return end.y + ((start.y - end.y) / 2)
    }

    /// The x-coordinate of the vertical middle segment of `edge`.
    private func verticalMidLine(
        _ start: Point, _ end: Point, _ direction: Side, _ edge: any Edge
    ) -> Int {
        precondition(direction.isVertical)
        precondition(EdgePriority.isSegmentedEdge(edge))
        let sharedNodeEdges = storage.edgesWithSameNodes(edge)
        if let first = sharedNodeEdges.first {
            return verticalMidlineForSharedNodeEdges(first, edge, direction)
        }
        if let closest = closestConflictingVerticalSegment(direction, edge) {
            return adjacentVerticalMidLine(closest, edge, direction)
        }
        return end.x + ((start.x - end.x) / 2)
    }

    /// The middle-line y-coordinate for an edge that shares both nodes with a stored one.
    private func horizontalMidlineForSharedNodeEdges(
        _ storedEdge: any Edge, _ newEdge: any Edge, _ direction: Side
    ) -> Int {
        precondition(direction.isHorizontal)
        let storedY = edgePath(storedEdge).point(at: 1).y
        return direction == .top ? storedY - Self.tenPixels : storedY + Self.tenPixels
    }

    /// The middle-line x-coordinate for an edge that shares both nodes with a stored one.
    private func verticalMidlineForSharedNodeEdges(
        _ storedEdge: any Edge, _ newEdge: any Edge, _ direction: Side
    ) -> Int {
        precondition(direction.isVertical)
        let storedX = edgePath(storedEdge).point(at: 1).x
        return direction == .left ? storedX - Self.tenPixels : storedX + Self.tenPixels
    }

    /// The closest stored edge whose horizontal middle segment may conflict with `edge`.
    private func closestConflictingHorizontalSegment(_ direction: Side, _ edge: any Edge) -> (any Edge)? {
        precondition(direction.isHorizontal)
        var conflicting = storedConflictingEdges(direction.mirrored(), edge.end(), edge)
        conflicting.append(contentsOf: storedConflictingEdges(direction, edge.start(), edge))
        if conflicting.isEmpty {
            return nil
        }
        let reference = edge is AggregationEdge ? edge.start() : edge.end()
        guard let reference else { return nil }
        return conflicting.min { lhs, rhs in
            verticalDistanceToNode(reference, lhs, direction) < verticalDistanceToNode(reference, rhs, direction)
        }
    }

    /// The closest stored edge whose vertical middle segment may conflict with `edge`.
    private func closestConflictingVerticalSegment(_ direction: Side, _ edge: any Edge) -> (any Edge)? {
        precondition(direction.isVertical)
        precondition(EdgePriority.isSegmentedEdge(edge))
        var conflicting = storedConflictingEdges(direction.mirrored(), edge.end(), edge)
        conflicting.append(contentsOf: storedConflictingEdges(direction, edge.start(), edge))
        if conflicting.isEmpty {
            return nil
        }
        let reference = edge is AggregationEdge ? edge.start() : edge.end()
        guard let reference else { return nil }
        return conflicting.min { lhs, rhs in
            horizontalDistanceToNode(reference, lhs, direction) < horizontalDistanceToNode(reference, rhs, direction)
        }
    }

    /// The middle-line y-coordinate for `edge`, offset by 10px from the conflicting edge.
    private func adjacentHorizontalMidLine(
        _ closest: any Edge, _ edge: any Edge, _ direction: Side
    ) -> Int {
        precondition(direction.isHorizontal)
        let commonNode = Self.sharedNode(closest, edge)
        let storedY = edgePath(closest).point(at: 1).y
        let outgoing = Self.isOutgoingEdge(edge, commonNode)
        if direction == .top {
            return outgoing ? storedY + Self.tenPixels : storedY - Self.tenPixels
        } else {
            return outgoing ? storedY - Self.tenPixels : storedY + Self.tenPixels
        }
    }

    /// The middle-line x-coordinate for `edge`, offset by 10px from the conflicting edge.
    private func adjacentVerticalMidLine(
        _ closest: any Edge, _ edge: any Edge, _ direction: Side
    ) -> Int {
        precondition(direction.isVertical)
        let commonNode = Self.sharedNode(closest, edge)
        let storedX = edgePath(closest).point(at: 1).x
        let outgoing = Self.isOutgoingEdge(edge, commonNode)
        if direction == .left {
            return outgoing ? storedX + Self.tenPixels : storedX - Self.tenPixels
        } else {
            return outgoing ? storedX - Self.tenPixels : storedX + Self.tenPixels
        }
    }

    // MARK: - Attachment sides

    /// The side of `node` that `edge` attaches to.
    private func attachedSide(_ edge: any Edge, _ node: any Node) -> Side {
        let sharedNodeEdges = storage.edgesWithSameNodes(edge)
        if let first = sharedNodeEdges.first {
            return attachedSideFromStorage(first, node)
        }
        let startAttachedSide: Side
        if edge is AggregationEdge {
            startAttachedSide = attachedSidePreferringEastWest(edge)
        } else {
            startAttachedSide = attachedSidePreferringNorthSouth(edge)
        }
        return Self.isOutgoingEdge(edge, node) ? startAttachedSide : startAttachedSide.mirrored()
    }

    /// East or West, unless the nodes are directly above or below each other.
    private func attachedSidePreferringEastWest(_ edge: any Edge) -> Side {
        guard let start = edge.start(), let end = edge.end() else { return .top }
        let startBounds = bounds.bounds(of: start)
        let endBounds = bounds.bounds(of: end)
        if startBounds.maxX > endBounds.x - (2 * Self.tenPixels)
            && startBounds.x < endBounds.maxX + (2 * Self.tenPixels) {
            return northSouthSideUnlessTooClose(edge)
        } else {
            return eastWestSideUnlessTooClose(edge)
        }
    }

    /// North or South, unless the nodes are directly beside each other.
    private func attachedSidePreferringNorthSouth(_ edge: any Edge) -> Side {
        guard let start = edge.start(), let end = edge.end() else { return .top }
        let startBounds = bounds.bounds(of: start)
        let endBounds = bounds.bounds(of: end)
        if startBounds.maxY > endBounds.y - (2 * Self.tenPixels)
            && startBounds.y < endBounds.maxY + (2 * Self.tenPixels) {
            return eastWestSideUnlessTooClose(edge)
        } else {
            return northSouthSideUnlessTooClose(edge)
        }
    }

    /// North or South, unless the nodes are closer than the middle segment.
    private func northSouthSideUnlessTooClose(_ edge: any Edge) -> Side {
        guard let start = edge.start(), let end = edge.end() else { return .top }
        let preferred = Self.northOrSouthSide(bounds.bounds(of: start), bounds.bounds(of: end))
        if nodeIsCloserThanSegment(edge, end, preferred)
            || nodeIsCloserThanSegment(edge, start, preferred.mirrored()) {
            return Self.eastOrWestSide(bounds.bounds(of: start), bounds.bounds(of: end))
        }
        return preferred
    }

    /// East or West, unless the nodes are closer than the middle segment.
    private func eastWestSideUnlessTooClose(_ edge: any Edge) -> Side {
        guard let start = edge.start(), let end = edge.end() else { return .top }
        let preferred = Self.eastOrWestSide(bounds.bounds(of: start), bounds.bounds(of: end))
        if nodeIsCloserThanSegment(edge, end, preferred)
            || nodeIsCloserThanSegment(edge, start, preferred.mirrored()) {
            return Self.northOrSouthSide(bounds.bounds(of: start), bounds.bounds(of: end))
        }
        return preferred
    }

    /// The side of the node on which a stored edge is attached.
    private func attachedSideFromStorage(_ edge: any Edge, _ node: any Node) -> Side {
        precondition(storage.contains(edge))
        var connectionPoint = edgePath(edge).startPoint
        if !Self.isOutgoingEdge(edge, node) {
            connectionPoint = edgePath(edge).endPoint
        }
        for side in Side.allCases {
            if bounds.face(of: node, side).spanning().contains(connectionPoint) {
                return side
            }
        }
        return .top
    }

    /// True if the other node attached to `edge` is closer to `node` than the edge's
    /// middle segment.
    private func nodeIsCloserThanSegment(_ edge: any Edge, _ node: any Node, _ attachedSide: Side) -> Bool {
        guard let otherNode = Self.otherNode(edge, node) else { return false }
        let otherNodeBounds = bounds.bounds(of: otherNode)
        let conflicting = storedConflictingEdges(attachedSide.mirrored(), node, edge)
        switch attachedSide {
        case .top:
            return conflicting.contains { otherNodeBounds.y < edgePath($0).point(at: 1).y - Self.tenPixels }
        case .bottom:
            return conflicting.contains { otherNodeBounds.maxY > edgePath($0).point(at: 1).y + Self.tenPixels }
        case .right:
            return conflicting.contains { otherNodeBounds.maxX > edgePath($0).point(at: 1).x - Self.tenPixels }
        case .left:
            return conflicting.contains { otherNodeBounds.x < edgePath($0).point(at: 1).x + Self.tenPixels }
        }
    }

    // MARK: - Connection points

    /// The point where `edge` connects to `node` on `side`, choosing the closest free
    /// `NodeIndex` to zero.
    private func connectionPoint(_ node: any Node, _ edge: any Edge, _ side: Side) -> Point {
        let face = bounds.face(of: node, side)
        let maxIndex = side.isVertical ? 2 : 4
        let indexSign = self.indexSign(edge, node, side)
        for offset in 0...maxIndex {
            let index = NodeIndex(rawValue: indexSign * offset)!
            let point = index.point(on: face, side: side)
            if storage.connectionPointIsAvailable(point) {
                return point
            }
        }
        return NodeIndex(rawValue: maxIndex * indexSign)!.point(on: face, side: side)
    }

    /// The index sign (-1 or 1) describing the attachment of `edge` on `node`.
    private func indexSign(_ edge: any Edge, _ node: any Node, _ side: Side) -> Int {
        let sharedNodeEdges = storage.edgesWithSameNodes(edge)
        if !sharedNodeEdges.isEmpty {
            guard let end = edge.end(), let start = edge.start() else { return 1 }
            return indexSignOnNode(edge, end, start, attachedSide(edge, end))
        }
        guard let other = Self.otherNode(edge, node) else { return 1 }
        return indexSignOnNode(edge, node, other, side)
    }

    /// Compares the relative positions of `node` and `otherNode` to pick the sign.
    private func indexSignOnNode(
        _ edge: any Edge, _ node: any Node, _ otherNode: any Node, _ side: Side
    ) -> Int {
        if side.isHorizontal {
            return bounds.bounds(of: node).center().x <= bounds.bounds(of: otherNode).center().x ? 1 : -1
        } else {
            return bounds.bounds(of: node).center().y <= bounds.bounds(of: otherNode).center().y ? 1 : -1
        }
    }

    /// Stored segmented edges attached to the given side of `node` that may conflict with
    /// `edge`.
    private func storedConflictingEdges(_ nodeSide: Side, _ node: (any Node)?, _ edge: any Edge) -> [any Edge] {
        guard let node else { return [] }
        return storage.edgesConnectedTo(node).filter { other in
            guard attachedSideFromStorage(other, node) == nodeSide else { return false }
            guard EdgePriority.isSegmentedEdge(other) else { return false }
            guard indexSign(other, node, nodeSide) == indexSign(edge, node, nodeSide) else { return false }
            return !(other === edge)
        }
    }

    // MARK: - Distances

    /// The distance between the top of `node` and the horizontal middle segment of `edge`.
    private func verticalDistanceToNode(_ node: any Node, _ edge: any Edge, _ direction: Side) -> Int {
        abs(edgePath(edge).point(at: 1).y - node.position.y)
    }

    /// The distance between the left side of `node` and the vertical middle segment of `edge`.
    private func horizontalDistanceToNode(_ node: any Node, _ edge: any Edge, _ direction: Side) -> Int {
        abs(edgePath(edge).point(at: 1).x - node.position.x)
    }

    // MARK: - Helpers

    /// The stored path of an edge.
    private func edgePath(_ edge: any Edge) -> EdgePath {
        precondition(storage.contains(edge))
        return storage.edgePath(edge)
    }

    /// The point of `points` farthest in `direction`.
    private static func closestPoint(_ points: [Point], _ direction: Side) -> Point {
        precondition(!points.isEmpty)
        switch direction {
        case .top:
            return points.min { $0.y < $1.y } ?? points[0]
        case .bottom:
            return points.max { $0.y < $1.y } ?? points[0]
        case .right:
            return points.max { $0.x < $1.x } ?? points[0]
        case .left:
            return points.min { $0.x < $1.x } ?? points[0]
        }
    }

    /// False if both edges are three-label edges with different start labels.
    private static func noConflictingStartLabels(_ edge1: any Edge, _ edge2: any Edge) -> Bool {
        guard let first = edge1 as? ThreeLabelEdge, let second = edge2 as? ThreeLabelEdge,
              EdgePriority.priority(of: edge1) == EdgePriority.priority(of: edge2) else {
            return true
        }
        return first.startLabel == second.startLabel
    }

    /// False if both edges are three-label edges with different end labels.
    private static func noConflictingEndLabels(_ edge1: any Edge, _ edge2: any Edge) -> Bool {
        guard let first = edge1 as? ThreeLabelEdge, let second = edge2 as? ThreeLabelEdge,
              EdgePriority.priority(of: edge1) == EdgePriority.priority(of: edge2) else {
            return true
        }
        return first.endLabel == second.endLabel
    }

    /// True if there are no stored edges attached between `edge1` and `edge2` on `node`.
    private func noOtherEdgesBetween(_ edge1: any Edge, _ edge2: any Edge, _ node: any Node) -> Bool {
        if edge1 === edge2 {
            return true
        }
        let side = attachedSide(edge1, node)
        let attached = storage.edgesConnectedTo(node).filter { attachedSide($0, node) == side }
        if attached.isEmpty {
            return true
        }
        guard let other1 = Self.otherNode(edge1, node), let other2 = Self.otherNode(edge2, node) else {
            return false
        }
        return nodesOnSameSideOfCommonNode(other1, other2, node, side)
    }

    /// True if the centres of two nodes are on the same side of the centre of a third.
    private func nodesOnSameSideOfCommonNode(
        _ node1: any Node, _ node2: any Node, _ commonNode: any Node, _ attachedSide: Side
    ) -> Bool {
        let node1Center = bounds.bounds(of: node1).center()
        let node2Center = bounds.bounds(of: node2).center()
        let commonCenter = bounds.bounds(of: commonNode).center()
        if attachedSide.isHorizontal {
            return (node1Center.x <= commonCenter.x && node2Center.x <= commonCenter.x)
                || (node1Center.x >= commonCenter.x && node2Center.x >= commonCenter.x)
        } else {
            return (node1Center.y <= commonCenter.y && node2Center.y <= commonCenter.y)
                || (node1Center.y >= commonCenter.y && node2Center.y >= commonCenter.y)
        }
    }

    /// The node that `edge1` and `edge2` are both attached to.
    private static func sharedNode(_ edge1: any Edge, _ edge2: any Edge) -> any Node {
        if let start = edge1.start(), let otherStart = edge2.start(),
           let otherEnd = edge2.end(), start === otherStart || start === otherEnd {
            return start
        }
        precondition(edge1.end() != nil)
        return edge1.end()!
    }

    /// True if `edge` starts at `node`.
    private static func isOutgoingEdge(_ edge: any Edge, _ node: any Node) -> Bool {
        if let start = edge.start() {
            return start === node
        }
        return false
    }

    /// The node attached to `edge` that is not `node`.
    private static func otherNode(_ edge: any Edge, _ node: any Node) -> (any Node)? {
        if let start = edge.start(), start === node {
            return edge.end()
        }
        return edge.start()
    }

    /// North or South depending on the relative vertical position of the two bounds.
    private static func northOrSouthSide(_ bounds: Rectangle, _ otherBounds: Rectangle) -> Side {
        otherBounds.center().y < bounds.center().y ? .top : .bottom
    }

    /// East or West depending on the relative horizontal position of the two bounds.
    private static func eastOrWestSide(_ bounds: Rectangle, _ otherBounds: Rectangle) -> Side {
        otherBounds.center().x < bounds.center().x ? .left : .right
    }

    /// Removes every edge of `edges` from `list`, by identity.
    private func removeAll(_ list: inout [any Edge], _ edges: [any Edge]) {
        list.removeAll { candidate in edges.contains { $0 === candidate } }
    }

    /// The `[startPoint, endPoint]` where a self-edge at `corner` of `node` would connect.
    public func toPoints(_ corner: NodeCorner, _ node: any Node) -> (start: Point, end: Point) {
        if corner == .topRight {
            let topFace = bounds.face(of: node, .top)
            let startPoint = Point(x: topFace.x2 - Self.twentyPixels, y: topFace.y2)
            let rightFace = bounds.face(of: node, .right)
            let endPoint = Point(x: rightFace.x1, y: rightFace.y1 + Self.twentyPixels)
            return (startPoint, endPoint)
        }
        let nodeBounds = bounds.bounds(of: node)
        switch corner {
        case .topLeft:
            return (Point(x: nodeBounds.x + Self.twentyPixels, y: nodeBounds.y),
                    Point(x: nodeBounds.x, y: nodeBounds.y + Self.twentyPixels))
        case .bottomLeft:
            return (Point(x: nodeBounds.x + Self.twentyPixels, y: nodeBounds.maxY),
                    Point(x: nodeBounds.x, y: nodeBounds.maxY - Self.twentyPixels))
        case .bottomRight:
            return (Point(x: nodeBounds.maxX - Self.twentyPixels, y: nodeBounds.maxY),
                    Point(x: nodeBounds.maxX, y: nodeBounds.maxY - Self.twentyPixels))
        case .topRight:
            preconditionFailure("handled above")
        }
    }
}
