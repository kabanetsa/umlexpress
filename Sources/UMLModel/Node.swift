//
//  Node.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.Node (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry

/// A node in a diagram.
///
/// Nodes that can act as child nodes may be linked to a parent node; nodes that can
/// act as parent nodes control their children. A diagram tracks only root nodes: if a
/// parent node is removed, all its children are removed with it, and cloning a parent
/// clones all children.
public protocol Node: DiagramElement {

    /// The position of this node, usually the top-left corner of its bounding box.
    var position: Point { get }

    /// Moves this node to `point`.
    func moveTo(_ point: Point)

    /// Translates this node by the given deltas.
    func translate(_ deltaX: Int, _ deltaY: Int)

    /// True iff this node is linked to a parent node.
    var hasParent: Bool { get }

    /// True iff a node of this type requires a parent to exist.
    var requiresParent: Bool { get }

    /// The parent node.
    /// - Precondition: `hasParent`.
    func getParent() -> any Node

    /// Unlinks this node from its parent. Does not remove it from the parent's
    /// children list.
    func unlink()

    /// Links this node to `parent`. Does not add it to the parent's children list.
    func link(_ parent: any Node)

    /// The children of this node; empty for node types that cannot have children.
    var children: [any Node] { get }

    /// True iff a node of `node`'s type may be a child of this node.
    func allowsAsChild(_ node: any Node) -> Bool

    /// Appends `node` to the children and links it to this node.
    func addChild(_ node: any Node)

    /// Inserts `node` as a child at `index` and links it to this node.
    func addChild(_ node: any Node, at index: Int)

    /// Removes `node` from the children and unlinks it.
    func removeChild(_ node: any Node)

    /// Moves the child to the last position in the children list.
    func placeLast(_ child: any Node)
}
