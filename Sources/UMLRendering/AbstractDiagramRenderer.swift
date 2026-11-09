//
//  AbstractDiagramRenderer.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.AbstractDiagramRenderer
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  Holds the registry of element renderers and the geometry queries that every diagram
//  renderer shares. `ClassDiagramRenderer` adds the edge-routing layouter on top.
//

import CoreGraphics
import Foundation
import UMLGeometry
import UMLModel

/// Base class for the diagram renderers: element renderers, geometry queries and drawing.
open class AbstractDiagramRenderer: RenderingContextOwner, NodeBoundsProvider,
    DiagramViewRendererBridge, EdgePathProviding {

    public let diagram: Diagram

    private var nodeRenderers: [ObjectIdentifier: any NodeRenderer] = [:]
    private var edgeRenderers: [ObjectIdentifier: any DiagramElementRenderer] = [:]

    public init(diagram: Diagram) {
        self.diagram = diagram
        // Renderers that are present in every diagram type.
        register(NoteNode.self, NoteNodeRenderer(self))
        register(PointNode.self, PointNodeRenderer(self))
        register(NoteEdge.self, NoteEdgeRenderer(self))
    }

    // MARK: - Registry

    /// Registers the renderer for a node type.
    public func register(_ nodeType: AnyClass, _ renderer: any NodeRenderer) {
        nodeRenderers[ObjectIdentifier(nodeType)] = renderer
    }

    /// Registers the renderer for an edge type.
    public func register(_ edgeType: AnyClass, _ renderer: any DiagramElementRenderer) {
        edgeRenderers[ObjectIdentifier(edgeType)] = renderer
    }

    /// The renderer for a node, looked up by dynamic type then by superclass.
    public func nodeRenderer(for node: any Node) -> any NodeRenderer {
        var currentType: AnyClass = Swift.type(of: node)
        while true {
            if let renderer = nodeRenderers[ObjectIdentifier(currentType)] {
                return renderer
            }
            guard let superclass = class_getSuperclass(currentType) else {
                preconditionFailure("no renderer registered for \(Swift.type(of: node))")
            }
            currentType = superclass
        }
    }

    /// The renderer for an edge, looked up by dynamic type then by superclass.
    public func edgeRenderer(for edge: any Edge) -> any DiagramElementRenderer {
        var currentType: AnyClass = Swift.type(of: edge)
        while true {
            if let renderer = edgeRenderers[ObjectIdentifier(currentType)] {
                return renderer
            }
            guard let superclass = class_getSuperclass(currentType) else {
                preconditionFailure("no renderer registered for \(Swift.type(of: edge))")
            }
            currentType = superclass
        }
    }

    /// All registered node renderers.
    public var allNodeRenderers: [any NodeRenderer] { Array(nodeRenderers.values) }

    // MARK: - Geometry

    /// The bounds of a node.
    public func bounds(of node: any Node) -> Rectangle {
        nodeRenderer(for: node).bounds(node)
    }

    /// The bounds of any element.
    public func boundsOf(_ element: any DiagramElement) -> Rectangle {
        if let node = element as? any Node {
            return bounds(of: node)
        }
        if let edge = element as? any Edge {
            return edgeRenderer(for: edge).bounds(edge)
        }
        preconditionFailure("unknown element type")
    }

    /// The connection point of a node in the given direction.
    public func connectionPoint(of node: any Node, _ direction: Direction) -> Point {
        nodeRenderer(for: node).connectionPoint(node, direction)
    }

    /// The face of a node on the given side.
    public func face(of node: any Node, _ side: Side) -> Line {
        nodeRenderer(for: node).face(of: node, side)
    }

    /// The default size of a node of this type.
    public func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        nodeRenderer(for: node).defaultDimension(node)
    }

    /// The bounds of a package node.
    public func packageBounds(_ node: PackageNode) -> Rectangle {
        bounds(of: node)
    }

    /// The bounds of the elements, extended to include their parents.
    public func boundsIncludingParents(_ elements: [any DiagramElement]) -> Rectangle {
        precondition(!elements.isEmpty)
        var result: Rectangle?
        for element in elements {
            var boundsForElement = boundsOf(element)
            var current: (any DiagramElement)? = element
            while let node = current as? any Node, node.hasParent {
                let parent = node.getParent()
                boundsForElement = boundsForElement.add(bounds(of: parent))
                current = parent
            }
            result = result.map { $0.add(boundsForElement) } ?? boundsForElement
        }
        return result!
    }

    /// The bounds of the elements, excluding their parents.
    public func boundsNotIncludingParents(_ elements: [any DiagramElement]) -> Rectangle {
        precondition(!elements.isEmpty)
        var result = boundsOf(elements[0])
        for element in elements.dropFirst() {
            result = result.add(boundsOf(element))
        }
        return result
    }

    /// True if the element contains the point.
    public func contains(_ element: any DiagramElement, _ point: Point) -> Bool {
        if let node = element as? any Node {
            return nodeRenderer(for: node).contains(node, point)
        }
        if let edge = element as? any Edge {
            return edgeRenderer(for: edge).contains(edge, point)
        }
        return false
    }

    /// The edge at a point, if any.
    public func edgeAt(_ point: Point) -> (any Edge)? {
        diagram.edges.first { edgeRenderer(for: $0).contains($0, point) }
    }

    /// The node at a point, if any; children win over their parents.
    public func nodeAt(_ point: Point) -> (any Node)? {
        for node in diagram.rootNodes.reversed() {
            if let found = deepFindNode(node, point) {
                return found
            }
        }
        return nil
    }

    private func deepFindNode(_ node: any Node, _ point: Point) -> (any Node)? {
        for child in node.children {
            if let found = deepFindNode(child, point) {
                return found
            }
        }
        return contains(node, point) ? node : nil
    }

    /// The selectable node at a point; point nodes are selectable like any other node.
    public func selectableNodeAt(_ point: Point) -> (any Node)? {
        nodeAt(point)
    }

    // MARK: - Stored edge paths

    /// Diagram renderers that plan edge paths override this; by default edges have none.
    open func storedEdgePath(_ edge: any Edge) -> EdgePath? {
        nil
    }

    // MARK: - Palette icons

    /// Renders the palette icon of an element, as the original renderers do.
    ///
    /// The icon shows a sample element of the same type when the element is one whose
    /// appearance depends on its text (an empty class would be an empty rectangle).
    public func icon(of element: any DiagramElement) -> CGImage? {
        if IconStyleSettings.current == .monogram {
            return IconRendering.monogram(IconStyleSettings.monogram(for: element))
        }
        let target = IconTemplates.template(for: element) ?? element
        if let node = target as? any Node {
            return nodeRenderer(for: node).createIcon(node)
        }
        if let edge = target as? any Edge {
            return edgeRenderer(for: edge).createIcon(edge)
        }
        return nil
    }

    // MARK: - Edge end points

    /// The points where an edge leaves its end nodes, as drawn.
    ///
    /// Class diagrams plan their edge routes, so the endpoints come from the stored path;
    /// the other diagram types compute them from the node faces.
    public func edgeEndPoints(_ edge: any Edge) -> (Point, Point)? {
        guard edge.start() != nil, edge.end() != nil else {
            return nil
        }
        if let path = storedEdgePath(edge) {
            return (path.startPoint, path.endPoint)
        }
        guard let renderer = edgeRenderer(for: edge) as? AbstractEdgeRenderer else {
            return nil
        }
        let line = renderer.connectionPoints(of: edge)
        return (line.point1, line.point2)
    }

    // MARK: - Drawing

    /// Draws every node, then every edge.
    public func draw(_ context: any RenderingContext) {
        activateNodeStorages()
        for node in diagram.rootNodes {
            drawNode(node, context)
        }
        drawEdges(context)
        deactivateAndClearNodeStorages()
    }

    /// Draws the edges; subclasses that plan paths override this.
    open func drawEdges(_ context: any RenderingContext) {
        for edge in diagram.edges {
            edgeRenderer(for: edge).draw(edge, context)
        }
    }

    /// Bridge method for the UI layer.
    public func drawDiagram(_ context: any RenderingContext) {
        draw(context)
    }

    private func drawNode(_ node: any Node, _ context: any RenderingContext) {
        nodeRenderer(for: node).draw(node, context)
        for child in node.children {
            drawNode(child, context)
        }
    }

    private func activateNodeStorages() {
        for renderer in nodeRenderers.values {
            renderer.activateNodeStorage()
        }
    }

    private func deactivateAndClearNodeStorages() {
        for renderer in nodeRenderers.values {
            renderer.deactivateAndClearNodeStorage()
        }
    }

    // MARK: - Bounds of the whole diagram

    /// The smallest rectangle that bounds the whole diagram, including labels.
    open func diagramBounds() -> Rectangle {
        var result: Rectangle?
        for node in diagram.allNodes {
            let nodeBounds = bounds(of: node)
            result = result.map { $0.add(nodeBounds) } ?? nodeBounds
        }
        for edge in diagram.edges {
            let edgeBounds = boundsOf(edge)
            result = result.map { $0.add(edgeBounds) } ?? edgeBounds
        }
        return result ?? Rectangle(x: 0, y: 0, width: 0, height: 0)
    }

    /// The diagram wrapped by this renderer.
    public var diagramModel: Diagram { diagram }
}
