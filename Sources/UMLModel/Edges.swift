//
//  Edges.swift
//  UMLExpress
//
//  Port of the edge types in org.jetuml.diagram.edges
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  Enum-valued properties are stored in `Properties` as their external string
//  representation (the case name), which is exactly what the Java code persists.
//

/// An edge that represents a UML aggregation or composition, with optional labels.
public final class AggregationEdge: ThreeLabelEdge {

    /// Type of aggregation relation.
    public enum AggregationType: String, CaseIterable, Sendable {
        case aggregation = "Aggregation"
        case composition = "Composition"
    }

    private var aggregationType: AggregationType = .aggregation

    public init(_ type: AggregationType) {
        self.aggregationType = type
        super.init()
    }

    public required init() {
        super.init()
    }

    public var type: AggregationType { aggregationType }

    public func setType(_ type: AggregationType) {
        aggregationType = type
    }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .aggregationType,
            get: { [unowned self] in self.aggregationType.rawValue },
            set: { [unowned self] value in
                self.aggregationType = AggregationType(rawValue: value as? String ?? "") ?? .aggregation
            })
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.aggregationType = aggregationType
        return duplicate
    }
}

/// An edge that represents a UML association, with optional labels and directionality.
public final class AssociationEdge: ThreeLabelEdge {

    /// Possible directionalities for an association.
    public enum Directionality: String, CaseIterable, Sendable {
        case unspecified = "Unspecified"
        case unidirectional = "Unidirectional"
        case bidirectional = "Bidirectional"
    }

    private var directionalityValue: Directionality = .unspecified

    public required init() { super.init() }

    public var directionality: Directionality { directionalityValue }

    public func setDirectionality(_ directionality: Directionality) {
        directionalityValue = directionality
    }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .directionality,
            get: { [unowned self] in self.directionalityValue.rawValue },
            set: { [unowned self] value in
                self.directionalityValue = Directionality(rawValue: value as? String ?? "") ?? .unspecified
            })
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.directionalityValue = directionalityValue
        return duplicate
    }
}

/// An edge that represents a UML dependency with an optional label. A dependency can be
/// unidirectional (from start to end) or bidirectional.
public final class DependencyEdge: SingleLabelEdge {

    /// Possible directionalities for a dependency.
    public enum Directionality: String, CaseIterable, Sendable {
        case unidirectional = "Unidirectional"
        case bidirectional = "Bidirectional"
    }

    private var directionalityValue: Directionality = .unidirectional

    public required init() { super.init() }

    public var directionality: Directionality { directionalityValue }

    public func setDirectionality(_ directionality: Directionality) {
        directionalityValue = directionality
    }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .directionality,
            get: { [unowned self] in self.directionalityValue.rawValue },
            set: { [unowned self] value in
                self.directionalityValue = Directionality(rawValue: value as? String ?? "") ?? .unidirectional
            })
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.directionalityValue = directionalityValue
        return duplicate
    }
}

/// An edge that represents a UML generalization (inheritance or implementation).
public final class GeneralizationEdge: AbstractEdge {

    /// Type of UML generalization relation.
    public enum GeneralizationType: String, CaseIterable, Sendable {
        case inheritance = "Inheritance"
        case implementation = "Implementation"
    }

    private var generalizationType: GeneralizationType = .inheritance

    public init(_ type: GeneralizationType) {
        self.generalizationType = type
        super.init()
    }

    public required init() {
        super.init()
    }

    public var type: GeneralizationType { generalizationType }

    public func setType(_ type: GeneralizationType) {
        generalizationType = type
    }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .generalizationType,
            get: { [unowned self] in self.generalizationType.rawValue },
            set: { [unowned self] value in
                self.generalizationType = GeneralizationType(rawValue: value as? String ?? "") ?? .inheritance
            })
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.generalizationType = generalizationType
        return duplicate
    }
}

/// An edge that joins two call nodes.
open class CallEdge: SingleLabelEdge {

    private var signalFlag = false

    public required init() {
        super.init()
        setSignal(false)
    }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .signal,
            get: { [unowned self] in self.signalFlag },
            set: { [unowned self] value in self.signalFlag = value as? Bool ?? false })
        return properties
    }

    public var isSignal: Bool { signalFlag }

    public func setSignal(_ newValue: Bool) {
        signalFlag = newValue
    }

    /// True if this is a self-edge: both call nodes are on the same implicit parameter.
    public var isSelfEdge: Bool {
        guard let end = end() as? CallNode, let start = start() else {
            return false
        }
        guard end.hasParent, start.hasParent else {
            return false
        }
        return end.getParent() === start.getParent()
    }

    open override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.signalFlag = signalFlag
        return duplicate
    }
}

/// An edge that joins the nodes in a constructor call.
public final class ConstructorEdge: CallEdge {

    public required init() {
        super.init()
        setMiddleLabel("\u{00AB}create\u{00BB}")
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.setMiddleLabel(middleLabel)
        return duplicate
    }
}

/// An edge that joins two call nodes and represents a return.
public final class ReturnEdge: SingleLabelEdge {
    public required init() { super.init() }
}

/// A line that connects a note to its attachment.
public final class NoteEdge: AbstractEdge {
    public required init() { super.init() }
}

/// An edge that represents a dynamic collaboration between two objects.
public final class ObjectCollaborationEdge: SingleLabelEdge {
    public required init() { super.init() }
}

/// An S- or C-shaped edge with an arrowhead.
public final class ObjectReferenceEdge: AbstractEdge {
    public required init() { super.init() }
}

/// A curved edge for a state transition in a state diagram.
public final class StateTransitionEdge: SingleLabelEdge {
    public required init() { super.init() }
}

/// An edge that represents an association between use cases.
public final class UseCaseAssociationEdge: AbstractEdge {
    public required init() { super.init() }
}

/// An edge that represents a UML dependency between use cases.
public final class UseCaseDependencyEdge: AbstractEdge {

    /// Type of use case dependency, with the corresponding edge label.
    public enum UseCaseDependencyType: String, CaseIterable, Sendable {
        case none = "None"
        case include = "Include"
        case extend = "Extend"

        /// The label that corresponds to this dependency type.
        public var label: String {
            switch self {
            case .none: ""
            case .include: "\u{00AB}include\u{00BB}"
            case .extend: "\u{00AB}extend\u{00BB}"
            }
        }
    }

    private var dependencyType: UseCaseDependencyType = .none

    public init(_ type: UseCaseDependencyType) {
        self.dependencyType = type
        super.init()
    }

    public required init() {
        super.init()
    }

    public var type: UseCaseDependencyType { dependencyType }

    public override func buildProperties() -> Properties {
        let properties = super.buildProperties()
        properties.add(
            .useCaseDependencyType,
            get: { [unowned self] in self.dependencyType.rawValue },
            set: { [unowned self] value in
                self.dependencyType = UseCaseDependencyType(rawValue: value as? String ?? "") ?? .none
            })
        return properties
    }

    public override func copy() -> Self {
        let duplicate = super.copy()
        duplicate.dependencyType = dependencyType
        return duplicate
    }
}

/// An edge that represents a generalization of a use case.
public final class UseCaseGeneralizationEdge: AbstractEdge {
    public required init() { super.init() }
}
