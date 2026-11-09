//
//  PackageNodes.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.nodes.AbstractPackageNode, PackageNode and
//  PackageDescriptionNode (JetUML 3.10, GPL-3, (C) McGill University).
//

/// Common data and behaviour for the different flavours of package nodes.
/// Package nodes have at least a name and a (possible) parent.
open class AbstractPackageNode: NamedNode {

    private var container: (any Node)?

    open override var hasParent: Bool { container != nil }

    open override func getParent() -> any Node {
        precondition(hasParent)
        return container!
    }

    open override func link(_ parent: any Node) {
        precondition(parent is PackageNode, "only package nodes can contain package nodes")
        container = parent
    }

    open override func unlink() {
        precondition(hasParent)
        container = nil
    }

    open override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.container = container
        return duplicate
    }
}

/// A package node in a UML diagram.
public final class PackageNode: AbstractPackageNode {

    private var containedNodes: [any Node] = []

    public required init() { super.init() }

    override public func translate(_ deltaX: Int, _ deltaY: Int) {
        super.translate(deltaX, deltaY)
        for child in containedNodes {
            child.translate(deltaX, deltaY)
        }
    }

    /// A deep copy: children are cloned and relinked to the copy. Children cannot be
    /// added through `addChild` because of the interaction with the original parent.
    public override func copy() -> PackageNode {
        let duplicate = super.copy()
        duplicate.containedNodes = []
        for child in containedNodes {
            let childCopy = child.copy()
            childCopy.link(duplicate)
            duplicate.containedNodes.append(childCopy)
        }
        return duplicate
    }

    override public var children: [any Node] { containedNodes }

    override public func addChild(_ node: any Node, at index: Int) {
        precondition(node is AbstractPackageNode || node is TypeNode)
        precondition(index >= 0 && index <= containedNodes.count)
        if node.hasParent {
            node.getParent().removeChild(node)
        }
        containedNodes.insert(node, at: index)
        node.link(self)
    }

    override public func addChild(_ node: any Node) {
        addChild(node, at: containedNodes.count)
    }

    override public func removeChild(_ node: any Node) {
        precondition(containedNodes.contains { $0 === node })
        precondition(node.hasParent && node.getParent() === self)
        containedNodes.removeAll { $0 === node }
        node.unlink()
    }

    override public func allowsAsChild(_ node: any Node) -> Bool {
        node is AbstractPackageNode || node is TypeNode
    }
}

/// A package description node in a UML diagram.
public final class PackageDescriptionNode: AbstractPackageNode {

    private var nodeContents = ""

    public required init() { super.init() }

    public func setContents(_ contents: String) {
        nodeContents = contents
    }

    public var contents: String { nodeContents }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .contents,
            get: { [unowned self] in self.nodeContents },
            set: { [unowned self] value in self.nodeContents = value as? String ?? "" })
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.nodeContents = nodeContents
        return duplicate
    }
}
