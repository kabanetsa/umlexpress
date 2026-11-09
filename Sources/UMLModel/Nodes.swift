//
//  Nodes.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.nodes.NamedNode, TypeNode, ClassNode, InterfaceNode
//  and NoteNode (JetUML 3.10, GPL-3, (C) McGill University).
//

/// A node with a name.
open class NamedNode: AbstractNode {

    private var nodeName = ""

    public func setName(_ name: String) {
        nodeName = name
    }

    public var name: String { nodeName }

    open override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .name,
            get: { [unowned self] in self.nodeName },
            set: { [unowned self] value in self.nodeName = value as? String ?? "" })
        return properties
    }

    open override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.nodeName = nodeName
        return duplicate
    }
}

/// A type that can represent either a class or an interface. A type node always has
/// methods and may have a container (package) as parent.
open class TypeNode: NamedNode {

    private var nodeMethods = ""
    private var container: (any Node)?

    public func setMethods(_ methods: String) {
        nodeMethods = methods
    }

    public var methods: String { nodeMethods }

    /// The attributes of this type node; the empty string by default.
    open var attributes: String { "" }

    public override var hasParent: Bool { container != nil }

    public override func getParent() -> any Node {
        precondition(hasParent)
        return container!
    }

    public override func link(_ parent: any Node) {
        precondition(parent is PackageNode, "only package nodes can contain type nodes")
        container = parent
    }

    public override func unlink() {
        precondition(hasParent)
        container = nil
    }

    public override var requiresParent: Bool { false }

    open override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .methods,
            get: { [unowned self] in self.nodeMethods },
            set: { [unowned self] value in self.nodeMethods = value as? String ?? "" })
        return properties
    }

    open override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.nodeMethods = nodeMethods
        duplicate.container = container
        return duplicate
    }
}

/// A class node in a class diagram.
public final class ClassNode: TypeNode {

    private var nodeAttributes = ""

    public required init() {
        super.init()
        setName("")
    }

    public func setAttributes(_ newValue: String) {
        nodeAttributes = newValue
    }

    public override var attributes: String { nodeAttributes }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.addAt(
            .attributes,
            get: { [unowned self] in self.nodeAttributes },
            set: { [unowned self] value in self.nodeAttributes = value as? String ?? "" },
            1)
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.nodeAttributes = nodeAttributes
        return duplicate
    }
}

/// An interface node in a class diagram.
public final class InterfaceNode: TypeNode {

    public override var attributes: String { "" }
}

/// A note node. The name of the node is the text of the note.
public final class NoteNode: NamedNode {
}
