//
//  Diagram.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.Diagram and org.jetuml.diagram.DiagramData
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

/// An element (typically the diagram) that can provide information about a diagram.
public protocol DiagramData {
    /// All the root nodes of the diagram.
    var rootNodes: [any Node] { get }
    /// All the edges of the diagram.
    var edges: [any Edge] { get }
}

/// The simple data model of a diagram: root nodes and edges.
///
/// Only root nodes are tracked explicitly; children are reached through their parent.
public final class Diagram: DiagramData {

    private var rootNodeList: [any Node] = []
    private var edgeList: [any Edge] = []
    private let kind: DiagramKind

    public init(kind: DiagramKind) {
        self.kind = kind
    }

    /// A copy of this diagram: a completely distinct graph with the same topology.
    public func duplicate() -> Diagram {
        let copy = Diagram(kind: kind)
        for edge in edgeList {
            copy.edgeList.append(edge.copy())
        }
        for node in rootNodeList {
            let nodeCopy = node.copy()
            copy.rootNodeList.append(nodeCopy)
            Diagram.reassignEdges(copy.edgeList, original: node, copy: nodeCopy)
        }
        // Reassign the diagram: re-connecting the edge refreshes its endpoints.
        for edge in copy.edgeList {
            if let start = edge.start(), let end = edge.end() {
                edge.connect(start, end)
            }
        }
        return copy
    }

    /// For `original`, replace it with `other` in all edges that refer to it, then do
    /// the same recursively for the children, assuming the same topology.
    private static func reassignEdges(_ edges: [any Edge], original: any Node, copy: any Node) {
        for edge in edges {
            if let start = edge.start(), start === original, let end = edge.end() {
                edge.connect(copy, end)
            }
            if let end = edge.end(), end === original, let start = edge.start() {
                edge.connect(start, copy)
            }
        }
        let oldChildren = original.children
        let newChildren = copy.children
        for index in 0..<min(oldChildren.count, newChildren.count) {
            reassignEdges(edges, original: oldChildren[index], copy: newChildren[index])
        }
    }

    public var rootNodes: [any Node] { rootNodeList }

    /// All the nodes in the diagram: the root nodes and their children, recursively.
    public var allNodes: [any Node] {
        var all: [any Node] = []
        for node in rootNodes {
            Diagram.collect(node, into: &all)
        }
        return all
    }

    private static func collect(_ parent: any Node, into nodes: inout [any Node]) {
        nodes.append(parent)
        for child in parent.children {
            collect(child, into: &nodes)
        }
    }

    public var edges: [any Edge] { edgeList }

    /// The type of this diagram.
    public var diagramKind: DiagramKind { kind }

    /// The file extension (including the dot) of this diagram type.
    public var fileExtension: String { kind.fileExtension }

    /// The name of this diagram.
    public var name: String { kind.name }

    /// True iff `element` is in the diagram. A node is in the diagram if it is a root
    /// node or any of its ancestors is a root node.
    public func contains(_ element: any DiagramElement) -> Bool {
        if edgeList.contains(where: { $0 === element }) {
            return true
        }
        return rootNodeList.contains { Diagram.contains(node: $0, target: element) }
    }

    private static func contains(node: any Node, target: any DiagramElement) -> Bool {
        if node === target {
            return true
        }
        return node.children.contains { contains(node: $0, target: target) }
    }

    /// True iff `node` is a root node of this diagram.
    public func containsAsRoot(_ node: any Node) -> Bool {
        rootNodeList.contains { $0 === node }
    }

    /// All edges connected to `node`.
    /// - Precondition: `node` is contained in the diagram.
    public func edgesConnectedTo(_ node: any Node) -> [any Edge] {
        precondition(contains(node))
        return edgeList.filter { edge in
            (edge.start().map { $0 === node } ?? false) || (edge.end().map { $0 === node } ?? false)
        }
    }

    /// All edges of type `type` (or a subtype) that end at `node`.
    public func edgesTo<T: Edge>(_ node: any Node, ofType type: T.Type) -> [any Edge] {
        edgeList.filter { edge in
            (edge as? T) != nil && (edge.end().map { $0 === node } ?? false)
        }
    }

    /// Adds `node` as a root node.
    public func addRootNode(_ node: any Node) {
        rootNodeList.append(node)
    }

    /// Removes `node` from the root nodes.
    /// - Precondition: `node` is a root node of this diagram.
    public func removeRootNode(_ node: any Node) {
        precondition(containsAsRoot(node))
        rootNodeList.removeAll { $0 === node }
    }

    /// Adds `edge`, which must already be connected to its start and end nodes.
    public func addEdge(_ edge: any Edge) {
        precondition(edge.start() != nil && edge.end() != nil)
        edgeList.append(edge)
    }

    /// Inserts `edge` at `index`.
    public func addEdge(_ edge: any Edge, at index: Int) {
        precondition(edge.start() != nil && edge.end() != nil)
        precondition(index >= 0 && index <= edgeList.count)
        edgeList.insert(edge, at: index)
    }

    /// The index of `edge` in the list of edges.
    /// - Precondition: the edge is contained in the diagram.
    public func indexOf(_ edge: any Edge) -> Int {
        precondition(contains(edge))
        guard let index = edgeList.firstIndex(where: { $0 === edge }) else {
            preconditionFailure("edge not found")
        }
        return index
    }

    /// Removes `edge` from the diagram.
    /// - Precondition: the edge is contained in the diagram.
    public func removeEdge(_ edge: any Edge) {
        precondition(contains(edge))
        edgeList.removeAll { $0 === edge }
    }

    /// Recursively reorders the node to be on top of its parent's children, or on top
    /// of the root nodes if it has no parent.
    public func placeOnTop(_ node: any Node) {
        // Certain nodes should not have their order changed.
        if type(of: node) == CallNode.self || type(of: node) == FieldNode.self {
            return
        }
        if node.hasParent {
            let parent = node.getParent()
            parent.placeLast(node)
            placeOnTop(parent)
        } else if containsAsRoot(node) {
            removeRootNode(node)
            addRootNode(node)
        }
    }
}
