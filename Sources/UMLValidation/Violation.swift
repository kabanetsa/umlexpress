//
//  Violation.swift, EdgeConstraint.swift, DiagramValidator.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.validator.Violation, EdgeConstraint and
//  DiagramValidator (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry
import UMLModel

/// A problem that invalidates a diagram for rendering.
public struct Violation: Equatable, Sendable {

    public enum Category: Sendable {
        case structural
        case semantic
    }

    /// The original prefixes resource keys with `error.`; the port keeps the key so
    /// that localized messages can be added later.
    private static let keyPrefix = "error."

    public let category: Category
    public let descriptor: String

    private init(_ category: Category, _ descriptor: String) {
        self.category = category
        self.descriptor = descriptor
    }

    /// A structural violation described by `descriptor`.
    public static func structural(_ descriptor: String) -> Violation {
        Violation(.structural, keyPrefix + descriptor)
    }

    /// A semantic violation caused by a constraint.
    public static func semantic(_ constraint: any EdgeConstraint) -> Violation {
        Violation(.semantic, keyPrefix + String(describing: type(of: constraint)))
    }

    /// True if this is a structural violation.
    public var isStructural: Bool { category == .structural }

    /// True if this is a semantic violation.
    public var isSemantic: Bool { category == .semantic }

    /// The externalized description of this violation.
    ///
    /// The original reads the localized string from the resource bundle; localization is
    /// not ported yet, so the resource key is returned (see the plan, §10).
    public var description: String { descriptor }
}

/// A constraint on how an edge is connected to nodes in a diagram.
public protocol EdgeConstraint: Sendable {
    /// True if the constraint is satisfied by the edge within the diagram.
    func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool
}

/// A type that checks a diagram's semantic validity.
public protocol DiagramValidator {
    /// The first violation detected, or `nil` if the diagram is valid.
    func validate() -> Violation?
}

extension DiagramValidator {
    /// True if the validation finds no violation.
    public var isValid: Bool { validate() == nil }
}

/// Scaffolding shared by the diagram validators.
///
/// Port of `AbstractDiagramValidator`: element-type checks, point-node checks and the
/// semantic constraints.
open class AbstractDiagramValidator: DiagramValidator {

    private static let descriptorInvalidElements = "StructureInvalidElements"
    private static let descriptorInvalidPoints = "StructureInvalidPoints"
    private static let descriptorInvalidNodes = "StructureInvalidNodes"

    /// Node types that are valid in every diagram.
    private static let universalNodeTypes: Set<ObjectIdentifier> = [
        ObjectIdentifier(PointNode.self), ObjectIdentifier(NoteNode.self),
    ]

    /// Edge types that are valid in every diagram.
    private static let universalEdgeTypes: Set<ObjectIdentifier> = [ObjectIdentifier(NoteEdge.self)]

    /// Constraints that apply to every diagram.
    private static let universalConstraints: [any EdgeConstraint] = [
        ConstraintValidNoteEdge(),
        ConstraintNoEdgeToPointExceptNoteEdge(),
        ConstraintNoEdgeToNoteExceptNoteEdge(),
        ConstraintNoSelfEdgeForEdgeType(NoteEdge.self),
    ]

    private let wrappedDiagram: Diagram
    private var validNodeTypes: Set<ObjectIdentifier>
    private var validEdgeTypes: Set<ObjectIdentifier>
    private var constraints: [any EdgeConstraint]

    public init(_ diagram: Diagram,
                nodeTypes: Set<ObjectIdentifier>,
                edgeTypes: Set<ObjectIdentifier>,
                constraints: [any EdgeConstraint]) {
        self.wrappedDiagram = diagram
        self.validNodeTypes = nodeTypes.union(Self.universalNodeTypes)
        self.validEdgeTypes = edgeTypes.union(Self.universalEdgeTypes)
        self.constraints = Self.universalConstraints + constraints
    }

    public final func validate() -> Violation? {
        if let violation = validateElementTypes() {
            return violation
        }
        if let violation = validatePointNodes() {
            return violation
        }
        if let violation = validateDiagramNodes() {
            return violation
        }
        return validateSemantics()
    }

    /// The diagram wrapped by this validator.
    public final var diagram: Diagram { wrappedDiagram }

    /// Diagram-specific node validation; succeeding by default.
    open func hasValidDiagramNodes() -> Bool {
        true
    }

    // MARK: - Steps

    private func validateElementTypes() -> Violation? {
        hasValidElementTypes() ? nil : .structural(Self.descriptorInvalidElements)
    }

    private func validatePointNodes() -> Violation? {
        hasValidPointNodes() ? nil : .structural(Self.descriptorInvalidPoints)
    }

    private func validateDiagramNodes() -> Violation? {
        hasValidDiagramNodes() ? nil : .structural(Self.descriptorInvalidNodes)
    }

    private func validateSemantics() -> Violation? {
        for edge in wrappedDiagram.edges {
            if let constraint = firstViolatedConstraint(for: edge) {
                return .semantic(constraint)
            }
        }
        return nil
    }

    private func firstViolatedConstraint(for edge: any Edge) -> (any EdgeConstraint)? {
        constraints.first { !$0.satisfied(edge, wrappedDiagram) }
    }

    private func hasValidElementTypes() -> Bool {
        wrappedDiagram.allNodes.allSatisfy { validNodeTypes.contains(ObjectIdentifier(type(of: $0))) }
            && wrappedDiagram.edges.allSatisfy { validEdgeTypes.contains(ObjectIdentifier(type(of: $0))) }
    }

    /// Point nodes must be connected to an edge.
    private func hasValidPointNodes() -> Bool {
        wrappedDiagram.rootNodes
            .filter { $0 is PointNode }
            .allSatisfy { !wrappedDiagram.edgesConnectedTo($0).isEmpty }
    }
}
