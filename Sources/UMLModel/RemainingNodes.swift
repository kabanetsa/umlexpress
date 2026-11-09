//
//  RemainingNodes.swift
//  UMLExpress
//
//  Port of the remaining node types from org.jetuml.diagram.nodes
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

/// An actor node in a use case diagram.
public final class ActorNode: NamedNode {

    /// The default name of an actor, as in the original.
    public static let defaultName = "Actor"

    public required init() {
        super.init()
        setName(Self.defaultName)
    }
}

/// A use case node in a use case diagram.
public final class UseCaseNode: NamedNode {
    public required init() { super.init() }
}

/// A state node in a state diagram.
public final class StateNode: NamedNode {
    public required init() { super.init() }
}

/// An initial state in a state diagram.
public final class InitialStateNode: AbstractNode {
    public required init() { super.init() }
    public override func copy() -> InitialStateNode {
        let duplicate = InitialStateNode()
        duplicate.moveTo(position)
        return duplicate
    }
}

/// A final state in a state diagram.
public final class FinalStateNode: AbstractNode {
    public required init() { super.init() }
    public override func copy() -> FinalStateNode {
        let duplicate = FinalStateNode()
        duplicate.moveTo(position)
        return duplicate
    }
}

/// An invisible node used in the toolbar to draw an edge, and in notes to serve as an
/// end point of the note connector.
public final class PointNode: AbstractNode {
    public required init() { super.init() }
    public override func copy() -> PointNode {
        let duplicate = PointNode()
        duplicate.moveTo(position)
        return duplicate
    }
}

/// An object node in an object diagram.
public final class ObjectNode: NamedNode {

    private var fields: [any Node] = []

    public required init() { super.init() }

    override public func translate(_ deltaX: Int, _ deltaY: Int) {
        super.translate(deltaX, deltaY)
        for child in fields {
            child.translate(deltaX, deltaY)
        }
    }

    /// A deep copy: fields are cloned and relinked to the copy.
    public override func copy() -> ObjectNode {
        let duplicate = super.copy()
        duplicate.fields = []
        for child in fields {
            let childCopy = child.copy()
            childCopy.link(duplicate)
            duplicate.fields.append(childCopy)
        }
        return duplicate
    }

    override public var children: [any Node] { fields }

    override public func addChild(_ node: any Node) {
        addChild(node, at: fields.count)
    }

    override public func addChild(_ node: any Node, at index: Int) {
        precondition(node is FieldNode)
        if node.hasParent {
            node.getParent().removeChild(node)
        }
        fields.insert(node, at: index)
        node.link(self)
    }

    override public func removeChild(_ node: any Node) {
        precondition(fields.contains { $0 === node })
        precondition(node.hasParent && node.getParent() === self)
        fields.removeAll { $0 === node }
        node.unlink()
    }

    override public func allowsAsChild(_ node: any Node) -> Bool {
        node is FieldNode
    }
}

/// A field node in an object diagram.
public final class FieldNode: NamedNode {

    private var fieldValue = "value"
    private var object: ObjectNode?

    public required init() {
        super.init()
        setName("name")
    }

    public func setValue(_ newValue: String) {
        fieldValue = newValue
    }

    public var value: String { fieldValue }

    public override var hasParent: Bool { object != nil }

    public override func getParent() -> any Node {
        precondition(hasParent)
        return object!
    }

    public override func link(_ parent: any Node) {
        guard let objectNode = parent as? ObjectNode else {
            preconditionFailure("only object nodes can contain field nodes")
        }
        object = objectNode
    }

    public override func unlink() {
        precondition(hasParent)
        object = nil
    }

    public override var requiresParent: Bool { true }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .value,
            get: { [unowned self] in self.fieldValue },
            set: { [unowned self] value in self.fieldValue = value as? String ?? "" })
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.fieldValue = fieldValue
        duplicate.object = object
        return duplicate
    }
}

/// An implicit parameter node in a sequence diagram. The visual portion of this node
/// includes the top rectangle (object) and its vertical life line.
public final class ImplicitParameterNode: NamedNode {

    private var callNodes: [any Node] = []

    public required init() { super.init() }

    /// A deep copy: call nodes are cloned and relinked to the copy.
    public override func copy() -> ImplicitParameterNode {
        let duplicate = super.copy()
        duplicate.callNodes = []
        for child in callNodes {
            let childCopy = child.copy()
            childCopy.link(duplicate)
            duplicate.callNodes.append(childCopy)
        }
        return duplicate
    }

    override public var children: [any Node] { callNodes }

    override public func addChild(_ node: any Node, at index: Int) {
        addChild(node)
    }

    override public func addChild(_ node: any Node) {
        precondition(node is CallNode)
        if node.hasParent {
            node.getParent().removeChild(node)
        }
        callNodes.append(node)
        node.link(self)
    }

    override public func removeChild(_ node: any Node) {
        precondition(callNodes.contains { $0 === node })
        precondition(node.hasParent && node.getParent() === self)
        callNodes.removeAll { $0 === node }
        node.unlink()
    }

    override public func allowsAsChild(_ node: any Node) -> Bool {
        node is CallNode
    }

    public override var description: String {
        "[ImplicitParameterNode: \(name)]"
    }
}

/// A method call node in a sequence diagram. Call nodes are not intended to be
/// manipulated by users.
open class CallNode: AbstractNode {

    /// The vertical gap between call nodes, as in the original.
    public static let callYGap = 20

    private var implicitParameter: ImplicitParameterNode?
    private var openBottomFlag = false

    public required init() { super.init() }

    public var isOpenBottom: Bool { openBottomFlag }

    public func setOpenBottom(_ newValue: Bool) {
        openBottomFlag = newValue
    }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .openBottom,
            get: { [unowned self] in self.openBottomFlag },
            set: { [unowned self] value in self.openBottomFlag = value as? Bool ?? false })
        return properties
    }

    open override var hasParent: Bool { implicitParameter != nil }

    public override func getParent() -> any Node {
        precondition(hasParent)
        return implicitParameter!
    }

    public override func link(_ parent: any Node) {
        guard let parameter = parent as? ImplicitParameterNode else {
            preconditionFailure("only implicit parameter nodes can contain call nodes")
        }
        implicitParameter = parameter
    }

    public override func unlink() {
        precondition(hasParent)
        implicitParameter = nil
    }

    public override var requiresParent: Bool { true }

    open override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.openBottomFlag = openBottomFlag
        duplicate.implicitParameter = implicitParameter
        return duplicate
    }

    public override var description: String {
        // The original dereferences the parent unconditionally, which throws for a
        // parentless node; the port degrades gracefully instead.
        guard hasParent else {
            return "[Call node without parent]"
        }
        let index = getParent().children.firstIndex { $0 === self } ?? 0
        return "[Call node #\(index + 1) of \(getParent())]"
    }
}
