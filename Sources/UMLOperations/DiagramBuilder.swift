//
//  DiagramBuilder.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.builder.DiagramBuilder
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The Java builder wraps a `DiagramRenderer` and creates the renderer itself; in this
//  port the renderer is injected through `DiagramViewRenderer`, so the operations module
//  does not depend on a particular diagram type's renderer.
//

import UMLGeometry
import UMLModel
import UMLRendering

/// The rendering services a builder needs, defined next to the renderer.
public typealias DiagramViewRenderer = DiagramViewRendererBridge

/// Converts requests to create or remove nodes and edges into undoable operations.
///
/// The class performs read-only access to the underlying diagram; executing the created
/// operations changes it.
open class DiagramBuilder {

    /// Arbitrary default value, used to simplify testing.
    private static let defaultDimension = 1000

    public let renderer: any DiagramViewRenderer
    private var canvasDimension = Dimension(width: defaultDimension, height: defaultDimension)

    public init(_ renderer: any DiagramViewRenderer) {
        self.renderer = renderer
    }

    /// The diagram wrapped by this builder.
    public final var diagram: Diagram { renderer.diagramModel }

    /// Informs the builder about the size of the canvas.
    public func setCanvasDimension(_ dimension: UMLGeometry.Dimension) {
        canvasDimension = dimension
    }

    // MARK: - Adding

    /// Positions the node so that it fits in the diagram, then adds it as a root node.
    open func createAddNodeOperation(_ node: any Node, _ requestedPosition: Point) -> any DiagramOperation {
        positionNode(node, requestedPosition)
        return SimpleOperation({ self.diagram.addRootNode(node) },
                               reverse: { self.diagram.removeRootNode(node) })
    }

    /// Creates an operation that adds all the elements, assuming nodes are roots and
    /// edges are connected.
    public final func createAddElementsOperation(_ elements: [any DiagramElement]) -> any DiagramOperation {
        let operation = CompoundOperation()
        for element in elements {
            if let node = element as? any Node {
                operation.add(SimpleOperation({ self.diagram.addRootNode(node) },
                                              reverse: { self.diagram.removeRootNode(node) }))
            } else if let edge = element as? any Edge {
                // Re-connect the edge so that it is properly attached after a copy.
                operation.add(SimpleOperation({
                    self.diagram.addEdge(edge)
                    if let start = edge.start(), let end = edge.end() {
                        edge.connect(start, end)
                    }
                }, reverse: { self.diagram.removeEdge(edge) }))
            }
        }
        return operation
    }

    // MARK: - Removing

    /// The elements that must be removed together with `element` to keep the diagram
    /// consistent.
    open func coRemovals(_ element: any DiagramElement) -> [any DiagramElement] {
        precondition(diagram.contains(element))
        var result: [any DiagramElement] = [element]

        if type(of: element) == PointNode.self, let node = element as? any Node {
            result.append(contentsOf: diagram.edgesConnectedTo(node))
        }
        if type(of: element) == NoteEdge.self, let edge = element as? any Edge {
            if let start = edge.start(), type(of: start) == PointNode.self {
                result.append(start)
            }
            if let end = edge.end(), type(of: end) == PointNode.self {
                result.append(end)
            }
        }
        if let node = element as? any Node {
            let descendants = Self.nodeAndAllChildren(node)
            for edge in diagram.edges {
                guard let start = edge.start(), let end = edge.end() else { continue }
                if descendants.contains(where: { $0 === start }) || descendants.contains(where: { $0 === end }) {
                    result.append(edge)
                    // Removing a note edge always removes its point nodes as well.
                    if edge is NoteEdge {
                        if type(of: start) == PointNode.self {
                            result.append(start)
                        }
                        if type(of: end) == PointNode.self {
                            result.append(end)
                        }
                    }
                }
            }
        }
        return result
    }

    /// Removes all the elements.
    public final func createRemoveElementsOperation(_ elements: [any DiagramElement]) -> any DiagramOperation {
        var toDelete: [any DiagramElement] = []
        for element in elements {
            for coRemoval in coRemovals(element) where !toDelete.contains(where: { $0 === coRemoval }) {
                toDelete.append(coRemoval)
            }
        }

        let result = CompoundOperation()
        for element in Self.orderForRemoval(toDelete, in: diagram) {
            if let edge = element as? any Edge {
                let index = diagram.indexOf(edge)
                result.add(SimpleOperation({ self.diagram.removeEdge(edge) },
                                           reverse: { self.diagram.addEdge(edge, at: index) }))
            } else if let node = element as? any Node {
                if node.hasParent {
                    result.add(SimpleOperation(Self.detachOperation(node, renderer: renderer),
                                               reverse: Self.reinsertOperation(node)))
                } else {
                    result.add(SimpleOperation({ self.diagram.removeRootNode(node) },
                                               reverse: { self.diagram.addRootNode(node) }))
                }
            }
        }
        return result
    }

    /// Orders the elements so that they can be reinserted properly: root nodes and
    /// parentless elements first, then edges (highest index first), then detached
    /// children (highest index first).
    static func orderForRemoval(_ elements: [any DiagramElement],
                                in diagram: Diagram) -> [any DiagramElement] {
        var straightforward: [any DiagramElement] = []
        var edges: [any Edge] = []
        var childNodes: [any Node] = []
        for element in elements {
            if let edge = element as? any Edge {
                edges.append(edge)
            } else if let node = element as? any Node, node.hasParent {
                childNodes.append(node)
            } else {
                straightforward.append(element)
            }
        }
        edges.sort { diagram.indexOf($0) > diagram.indexOf($1) }
        childNodes.sort { lhs, rhs in
            let parent1 = lhs.getParent()
            let parent2 = rhs.getParent()
            if parent1 === parent2 {
                let index1 = parent1.children.firstIndex { $0 === lhs } ?? 0
                let index2 = parent2.children.firstIndex { $0 === rhs } ?? 0
                return index2 < index1
            }
            let roots = diagram.rootNodes
            let index1 = roots.firstIndex { $0 === parent1 } ?? 0
            let index2 = roots.firstIndex { $0 === parent2 } ?? 0
            return index2 < index1
        }
        return straightforward + edges + childNodes
    }

    // MARK: - Moving

    /// Creates an operation that translates a node.
    public static func createMoveNodeOperation(_ node: any Node, _ x: Int, _ y: Int) -> any DiagramOperation {
        SimpleOperation({ node.translate(x, y) }, reverse: { node.translate(-x, -y) })
    }

    // MARK: - Edges

    /// Creates an operation that adds an edge between the nodes under `start` and `end`.
    public final func createAddEdgeOperation(_ edge: any Edge, _ start: Point, _ end: Point) -> any DiagramOperation {
        guard let startNode = renderer.nodeAt(start) else {
            preconditionFailure("an edge must start on a node")
        }
        let endNode = detectEndNode(edge, startNode, end)
        let finalEdge = obtainEdge(edge, start, end)

        let operation = CompoundOperation()
        if !diagram.allNodes.contains(where: { $0 === endNode }) {
            operation.add(SimpleOperation({ self.diagram.addRootNode(endNode) },
                                          reverse: { self.diagram.removeRootNode(endNode) }))
        }
        completeEdgeAdditionOperation(operation, finalEdge, startNode, endNode, start, end)
        return operation
    }

    /// Lets subclasses substitute a different edge type. Returns the original by default.
    open func obtainEdge(_ originalEdge: any Edge, _ start: Point, _ end: Point) -> any Edge {
        originalEdge
    }

    /// The end node for a new edge: the node under `end`, or a new point node (which is
    /// what note edges always use).
    open func detectEndNode(_ edge: any Edge, _ startNode: any Node, _ end: Point) -> any Node {
        let maybeEndNode = renderer.nodeAt(end)
        if (type(of: startNode) == NoteNode.self && type(of: edge) == NoteEdge.self) || maybeEndNode == nil {
            let endNode = PointNode()
            endNode.translate(end.x, end.y)
            return endNode
        }
        return maybeEndNode!
    }

    /// Connects the edge to the nodes and adds it to the diagram.
    open func completeEdgeAdditionOperation(_ operation: CompoundOperation, _ edge: any Edge,
                                            _ startNode: any Node, _ endNode: any Node,
                                            _ start: Point, _ end: Point) {
        edge.connect(startNode, endNode)
        operation.add(SimpleOperation({ self.diagram.addEdge(edge) },
                                      reverse: { self.diagram.removeEdge(edge) }))
    }

    // MARK: - Positioning

    /// Positions the node as close to the requested position as possible.
    open func positionNode(_ node: any Node, _ requestedPosition: Point) {
        let dimension = renderer.defaultDimension(node)
        let position = computePosition(dimension, requestedPosition)
        node.translate(position.x, position.y)
    }

    private func computePosition(_ dimension: UMLGeometry.Dimension, _ requested: Point) -> Point {
        var newX = requested.x
        var newY = requested.y
        if newX + dimension.width > canvasDimension.width {
            newX = canvasDimension.width - dimension.width
        }
        if newY + dimension.height > canvasDimension.height {
            newY = canvasDimension.height - dimension.height
        }
        return Point(x: newX, y: newY)
    }

    // MARK: - Helpers

    /// The node and all of its descendants.
    static func nodeAndAllChildren(_ node: any Node) -> [any Node] {
        var result: [any Node] = [node]
        for child in node.children {
            result.append(contentsOf: nodeAndAllChildren(child))
        }
        return result
    }

    private static func reinsertOperation(_ node: any Node) -> () -> Void {
        let parent = node.getParent()
        let index = parent.children.firstIndex { $0 === node } ?? 0
        return { parent.addChild(node, at: index) }
    }

    private static func detachOperation(_ node: any Node, renderer: any DiagramViewRenderer) -> () -> Void {
        let parent = node.getParent()
        if type(of: parent) == PackageNode.self, parent.children.count == 1, let package = parent as? PackageNode {
            // Removing the last child shrinks the package: keep its top-left corner.
            return {
                let parentBounds = renderer.packageBounds(package)
                parent.removeChild(node)
                parent.translate(parentBounds.x - parent.position.x, parentBounds.y - parent.position.y)
            }
        }
        return { parent.removeChild(node) }
    }
}
