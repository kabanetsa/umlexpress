//
//  AbstractNode.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.nodes.AbstractNode (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry

/// Common behaviour for the node hierarchy: position maintenance and the default
/// (unsupported) parent/child operations.
open class AbstractNode: AbstractDiagramElement, Node, CustomStringConvertible {

    private var currentPosition = Point(x: 0, y: 0)

    public func translate(_ deltaX: Int, _ deltaY: Int) {
        currentPosition = Point(x: currentPosition.x + deltaX, y: currentPosition.y + deltaY)
    }

    public final var position: Point { currentPosition }

    public final func moveTo(_ point: Point) {
        currentPosition = point
    }

    open override func copy() -> Self {
        let duplicate = type(of: self).init()
        duplicate.currentPosition = currentPosition.copy()
        return duplicate
    }

    open var hasParent: Bool { false }

    open var requiresParent: Bool { false }

    open func getParent() -> any Node {
        preconditionFailure("\(type(of: self)) does not support parents")
    }

    open func unlink() {
        preconditionFailure("\(type(of: self)) does not support parents")
    }

    open func link(_ parent: any Node) {
        preconditionFailure("\(type(of: self)) does not support parents")
    }

    open var children: [any Node] { [] }

    open func allowsAsChild(_ node: any Node) -> Bool { false }

    open func addChild(_ node: any Node) {
        precondition(self.allowsAsChild(node))
    }

    open func addChild(_ node: any Node, at index: Int) {
        precondition(self.allowsAsChild(node))
    }

    open func removeChild(_ node: any Node) {
        precondition(self.children.contains { $0 === node })
    }

    open func placeLast(_ child: any Node) {
        precondition(self.children.contains { $0 === child })
        removeChild(child)
        addChild(child)
    }

    /// The default description: the class name and the position.
    open var description: String {
        "\(type(of: self)) at \(position)"
    }
}
