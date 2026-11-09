//
//  TestSupport.swift
//  UMLExpress
//
//  Doubles used by the model tests. The Java tests use concrete nodes for these roles
//  (e.g. `PackageNode`); the model layer of the port is still partial, so minimal
//  stubs stand in for them.
//

import UMLGeometry
import UMLModel

/// A childless node, like `DiagramTest.StubNode` in the original tests. It supports a
/// parent link so that it can play the role of a child node (the original tests use
/// `ClassNode`, which inherits the parent support from `TypeNode`).
final class StubNode: AbstractNode {

    private var container: (any Node)?

    public required init() { super.init() }

    override var hasParent: Bool { container != nil }

    override func getParent() -> any Node {
        precondition(hasParent)
        return container!
    }

    override func link(_ parent: any Node) {
        container = parent
    }

    override func unlink() {
        container = nil
    }

    public override func copy() -> StubNode {
        let duplicate = StubNode()
        duplicate.moveTo(position)
        duplicate.container = container
        return duplicate
    }
}

/// A node that can have children, standing in for `PackageNode`.
final class StubParentNode: AbstractNode {

    private var childList: [any Node] = []

    public required init() { super.init() }

    override var children: [any Node] { childList }

    override func allowsAsChild(_ node: any Node) -> Bool { true }

    override func addChild(_ node: any Node) {
        childList.append(node)
    }

    override func addChild(_ node: any Node, at index: Int) {
        childList.insert(node, at: index)
    }

    override func removeChild(_ node: any Node) {
        childList.removeAll { $0 === node }
    }

    public override func copy() -> StubParentNode {
        let duplicate = StubParentNode()
        duplicate.moveTo(position)
        return duplicate
    }
}

/// A plain labelled edge, standing in for the concrete edge types.
final class StubEdge: SingleLabelEdge {
    public required init() { super.init() }
    public override func copy() -> StubEdge {
        let duplicate = StubEdge()
        duplicate.setMiddleLabel(middleLabel)
        if let start = start(), let end = end() {
            duplicate.connect(start, end)
        }
        return duplicate
    }
}

/// A second edge type, used to test type-based edge selection.
final class OtherStubEdge: SingleLabelEdge {
    public required init() { super.init() }
    public override func copy() -> OtherStubEdge {
        let duplicate = OtherStubEdge()
        duplicate.setMiddleLabel(middleLabel)
        if let start = start(), let end = end() {
            duplicate.connect(start, end)
        }
        return duplicate
    }
}
