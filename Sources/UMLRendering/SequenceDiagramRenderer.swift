//
//  SequenceDiagramRenderer.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.SequenceDiagramRenderer and the sequence-diagram node and
//  edge renderers (ImplicitParameterNodeRenderer, CallNodeRenderer, CallEdgeRenderer,
//  ReturnEdgeRenderer) — JetUML 3.10, GPL-3, (C) McGill University.
//

import CoreGraphics
import Foundation
import UMLGeometry
import UMLModel

/// The vertical layout of a sequence diagram, which node renderers query.
public protocol SequenceLayoutProvider: AnyObject {
    /// The y-coordinate of the top of a call node.
    func y(_ node: any Node) -> Int
    /// The y-coordinate of the bottom of a call node.
    func maxY(_ node: any Node) -> Int
    /// The y-coordinate of the top of an implicit parameter's lifeline.
    func lifelineTop(_ node: ImplicitParameterNode) -> Int
    /// The nesting depth of a call node on its parent.
    func nestingDepth(_ node: CallNode) -> Int
    /// The caller of a node, if any.
    func caller(_ node: any Node) -> CallNode?
    /// True if the top rectangle of the implicit parameter contains the point.
    func topRectangleContains(_ node: any Node, _ point: Point) -> Bool
    /// The x-coordinate of the centre of an implicit parameter.
    func centerX(_ node: ImplicitParameterNode) -> Int
}

/// The renderer for sequence diagrams.
///
/// The implementation assumes that a sequence diagram has either no call nodes or a
/// single root call node.
public final class SequenceDiagramRenderer: AbstractDiagramRenderer, SequenceLayoutProvider {

    static let constructorDrop = 5
    static let initialYPosition = 80
    static let dropMin = 20
    static let dropConstructor = 85
    static let bottomPadding = 20
    static let leafNodeHeight = 30
    private static let stringMetric = StringRenderer(.left)

    private var callNodeTopCoordinate: [ObjectIdentifier: Int] = [:]
    private var callNodeBottomCoordinate: [ObjectIdentifier: Int] = [:]

    public override init(diagram: Diagram) {
        precondition(diagram.diagramKind == .sequence)
        super.init(diagram: diagram)
        register(CallNode.self, CallNodeRenderer(self))
        register(ImplicitParameterNode.self, ImplicitParameterNodeRenderer(self))
        register(ReturnEdge.self, ReturnEdgeRenderer(self))
        register(CallEdge.self, CallEdgeRenderer(self))
        register(ConstructorEdge.self, CallEdgeRenderer(self))
    }

    // MARK: - Layout

    /// Computes the vertical positions of the call nodes.
    public func layout() {
        computeYPositions()
    }

    public override func draw(_ context: any RenderingContext) {
        layout()
        super.draw(context)
    }

    public override func diagramBounds() -> Rectangle {
        // Always recompute: the diagram can change (a node created by the editor, for
        // example) between two draws, and stale positions would leave a call node without
        // a y-coordinate.
        layout()
        return super.diagramBounds()
    }

    private func computeYPositions() {
        callNodeTopCoordinate.removeAll()
        callNodeBottomCoordinate.removeAll()
        var currentYPosition = Self.initialYPosition
        for root in roots() where callNodeTopCoordinate[ObjectIdentifier(root)] == nil {
            callNodeTopCoordinate[ObjectIdentifier(root)] = currentYPosition
            for callee in callees(root) {
                currentYPosition = computeYPosition(callee, currentYPosition)
            }
            callNodeBottomCoordinate[ObjectIdentifier(root)] = currentYPosition + Self.bottomPadding
        }
        // A diagram being edited can contain call nodes that the call tree does not reach
        // (an incomplete edit, for example); they are placed after the tree so that every
        // node has a position and the diagram can still be drawn.
        for node in diagram.allNodes where Swift.type(of: node) == CallNode.self
            && callNodeTopCoordinate[ObjectIdentifier(node)] == nil {
            currentYPosition += Self.dropDistance
            callNodeTopCoordinate[ObjectIdentifier(node)] = currentYPosition
            currentYPosition += Self.leafNodeHeight
            callNodeBottomCoordinate[ObjectIdentifier(node)] = currentYPosition
        }
    }

    private func computeYPosition(_ node: any Node, _ currentPosition: Int) -> Int {
        var position = currentPosition
        if isConstructorCall(node) {
            position += Self.dropConstructor
        } else {
            position += Self.dropDistance
        }
        callNodeTopCoordinate[ObjectIdentifier(node)] = position
        let callees = self.callees(node)
        if callees.isEmpty {
            position += Self.leafNodeHeight
        } else {
            for callee in callees {
                position = computeYPosition(callee, position)
            }
            position += Self.bottomPadding
        }
        callNodeBottomCoordinate[ObjectIdentifier(node)] = position
        return position
    }

    private static var dropDistance: Int {
        max(dropMin, stringMetric.dimension(of: "|").height)
    }

    /// True if the call node is the target of a constructor edge.
    func isConstructorCall(_ node: any Node) -> Bool {
        incomingCall(node) is ConstructorEdge
    }

    private func incomingCall(_ node: any Node) -> (any Edge)? {
        diagram.edges.first { edge in
            if let end = edge.end() {
                return end === node
            }
            return false
        }
    }

    // MARK: - SequenceLayoutProvider

    public func y(_ node: any Node) -> Int {
        // A node without a position (it was just created, or it is outside the call tree)
        // must not crash the renderer.
        callNodeTopCoordinate[ObjectIdentifier(node)] ?? Self.initialYPosition
    }

    public func maxY(_ node: any Node) -> Int {
        callNodeBottomCoordinate[ObjectIdentifier(node)]
            ?? (Self.initialYPosition + Self.leafNodeHeight)
    }

    /// The y-coordinate of the top of the lifeline of an implicit parameter.
    public func lifelineTop(_ node: ImplicitParameterNode) -> Int {
        let topNode = diagram.allNodes
            .filter { $0 is CallNode && ($0 as! CallNode).getParent() === (node as any Node) }
            .min { lhs, rhs in
                (callNodeTopCoordinate[ObjectIdentifier(lhs)] ?? Int.max)
                    < (callNodeTopCoordinate[ObjectIdentifier(rhs)] ?? Int.max)
            }
        guard let topNode, isConstructorCall(topNode) else {
            return Self.initialYPosition - Self.dropMin
        }
        return (callNodeTopCoordinate[ObjectIdentifier(topNode)] ?? Self.initialYPosition)
            - Self.constructorDrop
    }

    /// The caller of a node, if there is one.
    public func caller(_ node: any Node) -> CallNode? {
        for edge in diagram.edges where edge is CallEdge {
            if let end = edge.end(), end === node, let start = edge.start() as? CallNode {
                return start
            }
        }
        return nil
    }

    /// The number of call nodes active on the same parent when this call node executes.
    public func nestingDepth(_ node: CallNode) -> Int {
        var depth = 0
        guard node.hasParent else {
            return depth
        }
        var callerNode = caller(node)
        while let current = callerNode {
            if current.hasParent, current.getParent() === node.getParent() {
                depth += 1
            }
            callerNode = caller(current)
        }
        return depth
    }

    /// True if the top rectangle of the implicit parameter contains the point.
    public func topRectangleContains(_ node: any Node, _ point: Point) -> Bool {
        guard let parameter = node as? ImplicitParameterNode else {
            return false
        }
        return ImplicitParameterNodeRenderer.topRectangle(parameter, renderer: self).contains(point)
    }

    /// The x-coordinate of the centre of an implicit parameter.
    public func centerX(_ node: ImplicitParameterNode) -> Int {
        ImplicitParameterNodeRenderer.centerXCoordinate(node)
    }

    // MARK: - Call graph

    /// The roots of the call sequence: the call nodes without a caller.
    ///
    /// A valid diagram has exactly one, but the editor can be in an intermediate state
    /// (right after an edit), so several are tolerated and laid out in order.
    private func roots() -> [any Node] {
        let calledNodes = diagram.edges
            .filter { $0 is CallEdge }
            .compactMap { $0.end() }
        return diagram.allNodes.filter { node in
            Swift.type(of: node) == CallNode.self
                && !calledNodes.contains { $0 === node }
        }
    }

    /// The nodes directly called by `node`, in call order.
    private func callees(_ node: any Node) -> [any Node] {
        diagram.edges
            .filter { $0 is CallEdge }
            .compactMap { edge -> (any Node)? in
                guard let start = edge.start(), start === node else { return nil }
                return edge.end()
            }
    }

    /// True if there is at least one call node in the diagram.
    public var hasEntryPoint: Bool {
        diagram.rootNodes.contains { node in
            Swift.type(of: node) == ImplicitParameterNode.self && !node.children.isEmpty
        }
    }

    /// The start node of an edge if it is exclusive to that edge, so it can be removed
    /// together with it.
    public func startNodeIfExclusive(_ edge: any Edge) -> (any Node)? {
        if startNodeOnlyCalls(edge) {
            return edge.start()
        }
        if Swift.type(of: edge) == ConstructorEdge.self,
           let start = edge.start(),
           caller(start) == nil,
           onlyCallsToASingleImplicitParameterNode(start, edge.end()?.getParent()) {
            return start
        }
        return nil
    }

    private func startNodeOnlyCalls(_ edge: any Edge) -> Bool {
        guard let start = edge.start() else { return false }
        let calls = calls(start)
        return caller(start) == nil && calls.count == 1 && calls[0] === edge
    }

    private func onlyCallsToASingleImplicitParameterNode(_ caller: any Node, _ parent: (any Node)?) -> Bool {
        guard let parent else { return false }
        return calls(caller).allSatisfy { edge in
            guard let end = edge.end(), end.hasParent else { return false }
            return end.getParent() === parent
        }
    }

    /// The call edges starting at `caller`.
    public func calls(_ caller: any Node) -> [any Edge] {
        diagram.edges.filter { edge in
            guard edge is CallEdge, let start = edge.start() else { return false }
            return start === caller
        }
    }

    // MARK: - Selection

    /// Implicit parameter nodes can only be selected through their top rectangle.
    public override func selectableNodeAt(_ point: Point) -> (any Node)? {
        let topRectangleSelected = diagram.rootNodes.first { node in
            Swift.type(of: node) == ImplicitParameterNode.self
                && topRectangleContains(node, point)
        }
        return topRectangleSelected ?? super.selectableNodeAt(point)
    }

    /// Deep search that also descends into the callees of a call node.
    public override func nodeAt(_ point: Point) -> (any Node)? {
        for node in diagram.rootNodes.reversed() {
            if let found = deepFind(node, point) {
                return found
            }
        }
        return nil
    }

    private func deepFind(_ node: any Node, _ point: Point) -> (any Node)? {
        if Swift.type(of: node) == CallNode.self {
            for callee in callees(node) {
                if let found = deepFind(callee, point) {
                    return found
                }
            }
        }
        for child in node.children {
            if let found = deepFind(child, point) {
                return found
            }
        }
        return contains(node, point) ? node : nil
    }
}

// MARK: - Node renderers

/// Renders an implicit parameter: a top rectangle with the name and a dotted lifeline.
public final class ImplicitParameterNodeRenderer: AbstractNodeRenderer {

    public static let topHeight = 60
    static let defaultWidth = 80
    static let defaultHeight = 120
    private static let horizontalPadding = 10
    private static let tailHeight = 20
    private static let labelRenderer = StringRenderer(.center, .underlined)

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        Dimension(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    private var layout: any SequenceLayoutProvider {
        guard let provider = parent as? any SequenceLayoutProvider else {
            preconditionFailure("an implicit parameter node needs a sequence renderer")
        }
        return provider
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let node = element as? ImplicitParameterNode else {
            preconditionFailure("not an implicit parameter node")
        }
        let top = Self.topRectangle(node, renderer: layout)
        context.drawRectangle(top, fill: ColorScheme.current.fill,
                              stroke: ColorScheme.current.strokeColor,
                              hasShadow: ColorScheme.current.hasShadows)
        Self.labelRenderer.draw(node.name,
                                in: top.centerSlice(Self.labelRenderer.dimension(of: "|").height),
                                with: context)
        let xmid = top.center().x
        context.strokeLine(xmid, top.maxY, xmid, bounds(element).maxY,
                           ColorScheme.current.strokeColor, .dotted)
    }

    /// A small lifeline: the head box with a dotted tail, as in the original.
    ///
    /// The original draws the "lifeline" by itself, because an implicit parameter node
    /// cannot be drawn without a sequence layout.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        let iconWidth = Self.defaultWidth
        let iconHeight = Self.defaultHeight
        let scale = IconRendering.fitScale(width: iconWidth, height: iconHeight)
        let drawnWidth = Int((CGFloat(iconWidth) * scale).rounded())
        let drawnHeight = Int((CGFloat(iconHeight) * scale).rounded())
        let offsetX = CGFloat((IconRendering.buttonSize - drawnWidth) / 2)
        let offsetY = CGFloat((IconRendering.buttonSize - drawnHeight) / 2)
        return IconRendering.icon { context in
            let scaled = ScaledContext(context, scale: scale, offsetX: offsetX, offsetY: offsetY)
            let top = Rectangle(x: 0, y: 0, width: Self.defaultWidth, height: Self.topHeight)
            scaled.drawRectangle(top, fill: ColorScheme.current.fill,
                                 stroke: ColorScheme.current.strokeColor, hasShadow: false)
            scaled.strokeLine(Self.defaultWidth / 2, Self.topHeight, Self.defaultWidth / 2,
                              iconHeight, ColorScheme.current.strokeColor, .dotted)
        }
    }

    public override func contains(_ element: any DiagramElement, _ point: Point) -> Bool {
        let bounds = self.bounds(element)
        return bounds.x <= point.x && point.x <= bounds.x + bounds.width
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        let bounds = self.bounds(node)
        if direction == .east {
            return Point(x: bounds.maxX, y: bounds.y + Self.topHeight / 2)
        }
        return Point(x: bounds.x, y: bounds.y + Self.topHeight / 2)
    }

    static func width(_ node: any Node) -> Int {
        let label = (node as? ImplicitParameterNode)?.name ?? ""
        let labelWidth = labelRenderer.dimension(of: label).width
        return max(labelWidth + horizontalPadding, defaultWidth)
    }

    /// The rectangle at the top of the object node.
    public static func topRectangle(_ node: ImplicitParameterNode,
                                    renderer: any SequenceLayoutProvider) -> Rectangle {
        Rectangle(x: node.position.x,
                  y: renderer.lifelineTop(node) - topHeight,
                  width: width(node),
                  height: topHeight)
    }

    /// The x-coordinate of the centre of the node.
    public static func centerXCoordinate(_ node: any Node) -> Int {
        let label = (node as? ImplicitParameterNode)?.name ?? ""
        let labelWidth = labelRenderer.dimension(of: label).width
        return max(labelWidth + horizontalPadding, defaultWidth) / 2 + node.position.x
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        guard let node = node as? ImplicitParameterNode else {
            preconditionFailure("not an implicit parameter node")
        }
        let topRectangle = Self.topRectangle(node, renderer: layout)
        var maxX = 0
        var maxChildY = 0
        for child in node.children {
            let childBounds = parent.bounds(of: child)
            maxX = max(maxX, childBounds.maxX)
            maxChildY = max(maxChildY, childBounds.maxY)
        }
        let width = GeomUtils.max(topRectangle.width, Self.defaultWidth, maxX - node.position.x)
        let height = GeomUtils.max(Self.defaultHeight, maxChildY + Self.tailHeight) - topRectangle.y
        return Rectangle(x: node.position.x, y: topRectangle.y, width: width, height: height)
    }
}

/// Renders a call node: a narrow activation bar on its lifeline.
public final class CallNodeRenderer: AbstractNodeRenderer {

    private static let width = 16
    private static let defaultHeight = 30
    private static let nestingShiftDistance = 10

    private var layout: any SequenceLayoutProvider {
        guard let provider = parent as? any SequenceLayoutProvider else {
            preconditionFailure("a call node needs a sequence renderer")
        }
        return provider
    }

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        Dimension(width: Self.width, height: Self.defaultHeight)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        let bounds = self.bounds(element)
        let isOpenBottom = (element as? CallNode)?.isOpenBottom ?? false
        if !isOpenBottom {
            context.drawRectangle(bounds, fill: ColorScheme.current.fill,
                                  stroke: ColorScheme.current.strokeColor,
                                  hasShadow: ColorScheme.current.hasShadows)
            return
        }
        // An open-bottom activation bar: solid top part, dotted continuation.
        context.drawRectangle(bounds, fill: ColorScheme.current.fill,
                              stroke: ColorScheme.current.fill,
                              hasShadow: ColorScheme.current.hasShadows)
        let x1 = bounds.x
        let x2 = bounds.maxX
        let y1 = bounds.y
        let y3 = bounds.maxY
        let y2 = y3 - CallNode.callYGap
        context.strokeLine(x1, y1, x2, y1, ColorScheme.current.strokeColor, .solid)
        context.strokeLine(x1, y1, x1, y2, ColorScheme.current.strokeColor, .solid)
        context.strokeLine(x2, y1, x2, y2, ColorScheme.current.strokeColor, .solid)
        context.strokeLine(x1, y2, x1, y3, ColorScheme.current.strokeColor, .dotted)
        context.strokeLine(x2, y2, x2, y3, ColorScheme.current.strokeColor, .dotted)
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        let bounds = self.bounds(node)
        if direction == .east {
            return Point(x: bounds.maxX, y: bounds.y)
        }
        return Point(x: bounds.x, y: bounds.y)
    }

    private func x(_ node: any Node) -> Int {
        guard let callNode = node as? CallNode, callNode.hasParent,
              let parameter = callNode.getParent() as? ImplicitParameterNode else {
            return node.position.x
        }
        let nesting = layout.nestingDepth(callNode)
        let lifelineX = layout.centerX(parameter)
        return lifelineX - Self.nestingShiftDistance + Self.nestingShiftDistance * nesting
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        let y = layout.y(node)
        let maxY = layout.maxY(node)
        return Rectangle(x: x(node), y: y, width: Self.width, height: maxY - y)
    }
}

// MARK: - Edge renderers

/// Renders a call edge: a segmented line with a V or half-V arrow head.
public final class CallEdgeRenderer: AbstractEdgeRenderer {

    private static let centeredStringViewer = StringRenderer(.center)
    private static let topCenterStringRenderer = StringRenderer(.left)
    private static let leftMargin = 5

    static func arrowHead(_ edge: any Edge) -> ArrowHead {
        (edge as? CallEdge)?.isSignal == true ? .halfV : .v
    }

    /// A horizontal message arrow, as in the original (which draws it in a 0.6-scaled
    /// space); here the line spans the icon and only the head is drawn smaller.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        let y = IconRendering.buttonSize / 2
        let start = Point(x: IconRendering.offset, y: y)
        let end = Point(x: IconRendering.buttonSize - IconRendering.offset, y: y)
        return IconRendering.icon { context in
            context.strokeLine(start.x, start.y, end.x, end.y,
                               ColorScheme.current.strokeColor, .solid)
            ArrowHeadRenderer.draw(IconRendering.scaling(context,
                                                         by: IconRendering.decorationScale,
                                                         around: end),
                                   .v, start, end)
        }
    }

    public override func shape(of edge: any Edge) -> [PathCommand] {
        let points = self.points(edge)
        var commands: [PathCommand] = []
        commands.append(.move(to: points[points.count - 1]))
        for index in stride(from: points.count - 2, through: 0, by: -1) {
            commands.append(.line(to: points[index]))
        }
        return commands
    }

    public override func connectionPoints(of edge: any Edge) -> Line {
        let points = self.points(edge)
        return Line(point1: points[0], point2: points[points.count - 1])
    }

    public override func bounds(_ element: any DiagramElement) -> Rectangle {
        var bounds = super.bounds(element)
        guard let edge = element as? any Edge else { return bounds }
        bounds = bounds.add(ArrowHeadRenderer.bounds(Self.arrowHead(edge), connectionPoints(of: edge)))
        if !Self.label(edge).isEmpty {
            bounds = bounds.add(labelBox(edge))
        }
        return bounds
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let edge = element as? any Edge else { return }
        context.strokePath(shape(of: edge), color: ColorScheme.current.strokeColor, style: .solid)
        let points = self.points(edge)
        ArrowHeadRenderer.draw(context, Self.arrowHead(edge),
                               points[points.count - 2], points[points.count - 1])
        drawLabel(edge, context)
    }

    private static func label(_ edge: any Edge) -> String {
        (edge as? CallEdge)?.middleLabel ?? ""
    }

    private func labelBox(_ edge: any Edge) -> Rectangle {
        let label = Self.label(edge)
        if (edge as? CallEdge)?.isSelfEdge == true {
            let dimensions = Self.topCenterStringRenderer.dimension(of: label)
            let points = self.points(edge)
            let x = points[1].x + Self.leftMargin
            let y = (points[1].y + points[2].y) / 2 - dimensions.height / 2
            return Rectangle(x: x, y: y, width: dimensions.width, height: dimensions.height)
        }
        let spanning = connectionPoints(of: edge).spanning()
        let lineHeight = Self.centeredStringViewer.dimension(of: label).height
        return Rectangle(x: spanning.x, y: spanning.y - lineHeight,
                         width: spanning.width, height: lineHeight)
    }

    private func drawLabel(_ edge: any Edge, _ context: any RenderingContext) {
        let label = Self.label(edge)
        guard !label.isEmpty else { return }
        if (edge as? CallEdge)?.isSelfEdge == true {
            Self.topCenterStringRenderer.draw(label, in: labelBox(edge), with: context)
        } else {
            Self.centeredStringViewer.draw(label, in: labelBox(edge), with: context)
        }
    }

    /// The segmented path of a call edge.
    func points(_ edge: any Edge) -> [Point] {
        guard let startNode = edge.start(), let rawEnd = edge.end() else {
            preconditionFailure("edge is not connected")
        }
        let endNode: any Node = Swift.type(of: edge) == ConstructorEdge.self
            && rawEnd.hasParent ? rawEnd.getParent() : rawEnd
        let start = parent.bounds(of: startNode)
        let end = parent.bounds(of: endNode)
        if (edge as? CallEdge)?.isSelfEdge == true {
            let p = Point(x: start.maxX, y: end.y - CallNode.callYGap / 2)
            let q = Point(x: end.maxX, y: end.y)
            let s = Point(x: q.x + end.width, y: q.y)
            let r = Point(x: s.x, y: p.y)
            return [p, r, s, q]
        }
        var direction = Direction.west
        if start.x > end.x {
            direction = .east
        }
        let endPoint = parent.connectionPoint(of: endNode, direction)
        if start.center().x < endPoint.x {
            return [Point(x: start.maxX, y: endPoint.y), endPoint]
        }
        return [Point(x: start.x, y: endPoint.y), endPoint]
    }
}

/// Renders a return edge: a dotted straight line with a V arrow head.
public final class ReturnEdgeRenderer: LabeledStraightEdgeRenderer {

    public init(_ parent: any RenderingContextOwner & EdgePathProviding) {
        super.init(parent, .dotted, .v) { edge in
            (edge as? ReturnEdge)?.middleLabel ?? ""
        }
    }

    /// A dotted message arrow, as in the original; the line spans the icon and only the
    /// head is drawn smaller.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        let y = IconRendering.buttonSize / 2
        let start = Point(x: IconRendering.offset, y: y)
        let end = Point(x: IconRendering.buttonSize - IconRendering.offset, y: y)
        return IconRendering.icon { context in
            context.strokeLine(start.x, start.y, end.x, end.y,
                               ColorScheme.current.strokeColor, .dotted)
            ArrowHeadRenderer.draw(IconRendering.scaling(context,
                                                         by: IconRendering.decorationScale,
                                                         around: start),
                                   .v, end, start)
        }
    }

    public override func connectionPoints(of edge: any Edge) -> Line {
        guard let startNode = edge.start(), let endNode = edge.end() else {
            preconditionFailure("edge is not connected")
        }
        let start = parent.bounds(of: startNode)
        let end = parent.bounds(of: endNode)
        if endNode is PointNode {
            // Nicely displayed in the tool palette.
            return Line(point1: Point(x: end.x, y: end.y),
                        point2: Point(x: start.maxX, y: end.y))
        }
        if start.center().x < end.center().x {
            return Line(point1: Point(x: start.maxX, y: start.maxY),
                        point2: Point(x: end.x, y: start.maxY))
        }
        return Line(point1: Point(x: start.x, y: start.maxY),
                    point2: Point(x: end.maxX, y: start.maxY))
    }
}
