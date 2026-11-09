//
//  SequenceDiagramBuilder.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.builder.SequenceDiagramBuilder
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry
import UMLModel
import UMLRendering

/// A builder for sequence diagrams: creating a call edge creates the call nodes it needs.
public final class SequenceDiagramBuilder: DiagramBuilder {

    private static let callNodeYGap = 5

    public override init(_ renderer: any DiagramViewRenderer) {
        precondition(renderer.diagramModel.diagramKind == .sequence)
        super.init(renderer)
    }

    public convenience init(_ diagram: Diagram) {
        self.init(SequenceDiagramRenderer(diagram: diagram))
    }

    private var sequenceRenderer: SequenceDiagramRenderer {
        guard let renderer = renderer as? SequenceDiagramRenderer else {
            preconditionFailure("a sequence builder needs a sequence renderer")
        }
        return renderer
    }

    // MARK: - Adding

    /// A call node dropped on a lifeline becomes a child of the implicit parameter.
    public override func createAddNodeOperation(_ node: any Node,
                                                _ requestedPosition: Point) -> any DiagramOperation {
        if node is CallNode, let target = insideTargetArea(requestedPosition) {
            return SimpleOperation({ target.addChild(node) }, reverse: { target.removeChild(node) })
        }
        return super.createAddNodeOperation(node, requestedPosition)
    }

    /// The implicit parameter under the point, below its top rectangle.
    private func insideTargetArea(_ point: Point) -> ImplicitParameterNode? {
        for node in diagram.rootNodes {
            guard let parameter = node as? ImplicitParameterNode, renderer.contains(parameter, point) else {
                continue
            }
            let top = ImplicitParameterNodeRenderer.topRectangle(parameter, renderer: sequenceRenderer)
            if !(point.y < top.maxY + Self.callNodeYGap) {
                return parameter
            }
        }
        return nil
    }

    /// Replaces a call edge with a constructor edge when the target is an empty object.
    public override func obtainEdge(_ originalEdge: any Edge, _ start: Point, _ end: Point) -> any Edge {
        if Swift.type(of: originalEdge) == CallEdge.self, canCreateConstructorCall(start, end) {
            return ConstructorEdge()
        }
        return super.obtainEdge(originalEdge, start, end)
    }

    private func canCreateConstructorCall(_ start: Point, _ end: Point) -> Bool {
        guard let startNode = renderer.nodeAt(start), let endNode = renderer.nodeAt(end) else {
            return false
        }
        let validStart = Swift.type(of: startNode) == ImplicitParameterNode.self
            || Swift.type(of: startNode) == CallNode.self
        guard validStart else { return false }
        return Swift.type(of: endNode) == ImplicitParameterNode.self
            && sequenceRenderer.topRectangleContains(endNode, end)
            && endNode.children.isEmpty
    }

    /// Creates the call nodes needed by a call edge and inserts the edge in call order.
    public override func completeEdgeAdditionOperation(_ operation: CompoundOperation, _ edge: any Edge,
                                                       _ startNode: any Node, _ endNode: any Node,
                                                       _ start: Point, _ end: Point) {
        guard edge is CallEdge else {
            super.completeEdgeAdditionOperation(operation, edge, startNode, endNode, start, end)
            return
        }
        // The insertion point is looked up through the call layout, which must reflect the
        // calls already in the diagram.
        sequenceRenderer.layout()
        guard Self.validCallEdgeSemantics(startNode, endNode) else {
            edge.connect(startNode, endNode)
            operation.add(SimpleOperation({ self.diagram.addEdge(edge) },
                                          reverse: { self.diagram.removeEdge(edge) }))
            return
        }

        var effectiveStart = startNode
        if Swift.type(of: startNode) == ImplicitParameterNode.self,
           let parent = startNode as? ImplicitParameterNode {
            let newCallNode = CallNode()
            operation.add(SimpleOperation({ parent.addChild(newCallNode) },
                                          reverse: { parent.removeChild(newCallNode) }))
            effectiveStart = newCallNode
        }

        let endParent: ImplicitParameterNode
        if let parameter = endNode as? ImplicitParameterNode {
            endParent = parameter
        } else {
            endParent = endNode.getParent() as! ImplicitParameterNode
        }
        let newEnd = CallNode()
        operation.add(SimpleOperation({ endParent.addChild(newEnd) },
                                      reverse: { endParent.removeChild(newEnd) }))

        let insertionIndex = computeInsertionIndex(effectiveStart, start.y)
        edge.connect(effectiveStart, newEnd)
        operation.add(SimpleOperation({ self.diagram.addEdge(edge, at: insertionIndex) },
                                      reverse: { self.diagram.removeEdge(edge) }))
    }

    private static func validCallEdgeSemantics(_ startNode: any Node, _ endNode: any Node) -> Bool {
        let validStart = Swift.type(of: startNode) == ImplicitParameterNode.self
            || Swift.type(of: startNode) == CallNode.self
        let validEnd = Swift.type(of: endNode) == ImplicitParameterNode.self
            || Swift.type(of: endNode) == CallNode.self
        return validStart && validEnd
    }

    /// The index at which the new call edge should be inserted to keep call order.
    private func computeInsertionIndex(_ caller: any Node, _ y: Int) -> Int {
        for callee in sequenceRenderer.calls(caller) where calleeY(callee) > y {
            return diagram.indexOf(callee)
        }
        return diagram.edges.count
    }

    private func calleeY(_ edge: any Edge) -> Int {
        guard let end = edge.end() else { return 0 }
        return sequenceRenderer.y(end)
    }

    // MARK: - Removing

    /// Removing an element of a sequence also removes the calls that make no sense
    /// without it.
    public override func coRemovals(_ element: any DiagramElement) -> [any DiagramElement] {
        var result = super.coRemovals(element)
        if let node = element as? any Node {
            result.append(contentsOf: Self.upstreams(of: node, renderer: sequenceRenderer))
            result.append(contentsOf: Self.downstreams(of: node, renderer: sequenceRenderer))
        } else if let edge = element as? any Edge {
            if let start = sequenceRenderer.startNodeIfExclusive(edge) {
                result.append(start)
            }
            result.append(contentsOf: Self.edgeDownstreams(edge, renderer: sequenceRenderer))
        }
        // Return edges corresponding to the removed calls go away as well.
        for callEdge in result.compactMap({ $0 as? CallEdge }) {
            if let returnEdge = correspondingReturnEdge(callEdge) {
                result.append(returnEdge)
            }
        }
        if element is ConstructorEdge {
            result.removeAll { $0 is ImplicitParameterNode }
        }
        return result
    }

    private func correspondingReturnEdge(_ callEdge: any Edge) -> (any Edge)? {
        diagram.edges.first { other in
            guard other is ReturnEdge, let start = other.start(), let end = other.end(),
                  let callStart = callEdge.start(), let callEnd = callEdge.end() else {
                return false
            }
            return start === callEnd && end === callStart
        }
    }

    // MARK: - Call graph helpers

    private static func upstreams(of node: any Node,
                                  renderer: SequenceDiagramRenderer) -> [any DiagramElement] {
        var elements: [any DiagramElement] = []
        if Swift.type(of: node) == CallNode.self {
            if let callerNode = renderer.caller(node), renderer.caller(callerNode) == nil {
                let calls = renderer.calls(callerNode)
                if calls.count == 1, let end = calls[0].end(), end === node {
                    elements.append(callerNode)
                }
            }
        } else if Swift.type(of: node) == ImplicitParameterNode.self,
                  let firstChild = node.children.first,
                  let callerNode = renderer.caller(firstChild),
                  renderer.caller(callerNode) == nil {
            elements.append(callerNode)
        }
        return elements
    }

    private static func downstreams(of node: any Node,
                                    renderer: SequenceDiagramRenderer) -> [any DiagramElement] {
        var elements: [any DiagramElement] = []
        if Swift.type(of: node) == CallNode.self {
            for edge in renderer.calls(node) {
                elements.append(contentsOf: edgeDownstreams(edge, renderer: renderer))
            }
        } else if Swift.type(of: node) == ImplicitParameterNode.self {
            elements.append(contentsOf: node.children)
            for child in node.children {
                for edge in renderer.calls(child) {
                    elements.append(contentsOf: edgeDownstreams(edge, renderer: renderer))
                }
            }
        }
        return elements
    }

    static func edgeDownstreams(_ edge: any Edge,
                                renderer: SequenceDiagramRenderer) -> [any DiagramElement] {
        var elements: [any DiagramElement] = [edge]
        if edge is ConstructorEdge, let endNode = edge.end(), endNode.hasParent {
            let endParent = endNode.getParent()
            elements.append(endParent)
            elements.append(contentsOf: endParent.children)
            for child in endParent.children {
                for callEdge in renderer.calls(child) {
                    elements.append(contentsOf: edgeDownstreams(callEdge, renderer: renderer))
                }
                for upstream in renderer.diagramModel.edges {
                    if let end = upstream.end(), end === child {
                        elements.append(upstream)
                    }
                }
            }
        } else if edge is CallEdge, let endNode = edge.end() {
            elements.append(endNode)
            for callEdge in renderer.calls(endNode) {
                elements.append(contentsOf: edgeDownstreams(callEdge, renderer: renderer))
            }
        }
        return elements
    }
}

extension DiagramBuilderFactory {
    /// The builder for the given diagram.
    public static func builder(for diagram: Diagram) -> DiagramBuilder {
        switch diagram.diagramKind {
        case .class: ClassDiagramBuilder(diagram)
        case .state: StateDiagramBuilder(diagram)
        case .object: ObjectDiagramBuilder(diagram)
        case .useCase: UseCaseDiagramBuilder(diagram)
        case .sequence: SequenceDiagramBuilder(diagram)
        }
    }
}
