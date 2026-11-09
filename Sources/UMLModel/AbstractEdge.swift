//
//  AbstractEdge.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.edges.AbstractEdge (JetUML 3.10, GPL-3, (C) McGill University).
//

/// Groups the functionality common to all edges.
open class AbstractEdge: AbstractDiagramElement, Edge, CustomStringConvertible {

    private var startNode: (any Node)?
    private var endNode: (any Node)?

    public final func connect(_ start: any Node, _ end: any Node) {
        startNode = start
        endNode = end
    }

    open func start() -> (any Node)? { startNode }

    open func end() -> (any Node)? { endNode }

    open override func copy() -> Self {
        // Start and end nodes are shallow-copied, as in the original.
        let duplicate = type(of: self).init()
        duplicate.startNode = startNode
        duplicate.endNode = endNode
        return duplicate
    }

    open var description: String {
        let typeName = String(describing: type(of: self))
        if let startNode, let endNode {
            return "\(typeName) \(startNode) -> \(endNode)"
        }
        return typeName
    }
}
