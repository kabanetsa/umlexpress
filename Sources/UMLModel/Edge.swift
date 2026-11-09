//
//  Edge.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.Edge (JetUML 3.10, GPL-3, (C) McGill University).
//

/// An edge in a diagram.
public protocol Edge: DiagramElement {

    /// Connects this edge to two nodes.
    func connect(_ start: any Node, _ end: any Node)

    /// The start node, or `nil` if the edge is not connected yet (the original
    /// returns `null` in that case).
    func start() -> (any Node)?

    /// The end node, or `nil` if the edge is not connected yet.
    func end() -> (any Node)?
}
