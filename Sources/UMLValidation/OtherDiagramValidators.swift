//
//  OtherDiagramValidators.swift
//  UMLExpress
//
//  Port of the remaining diagram validators and their constraints
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLModel

// MARK: - Constraints

/// A transition can only start in an initial node or a state node.
public struct ConstraintValidTransitionEdgeStartNode: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard type(of: edge) == StateTransitionEdge.self else { return true }
        guard let start = edge.start() else { return false }
        return type(of: start) == InitialStateNode.self || type(of: start) == StateNode.self
    }
}

/// A transition can only end in a final node or a state node.
public struct ConstraintValidTransitionEdgeEndNode: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard type(of: edge) == StateTransitionEdge.self else { return true }
        guard let end = edge.end() else { return false }
        return type(of: end) == FinalStateNode.self || type(of: end) == StateNode.self
    }
}

/// A reference edge can only be between an object node and a field node.
public struct ConstraintValidReferenceEdge: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard type(of: edge) == ObjectReferenceEdge.self else { return true }
        guard let start = edge.start(), let end = edge.end() else { return false }
        return type(of: start) == FieldNode.self && type(of: end) == ObjectNode.self
    }
}

/// A collaboration edge can only be between two object nodes.
public struct ConstraintValidCollaborationEdge: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard type(of: edge) == ObjectCollaborationEdge.self else { return true }
        guard let start = edge.start(), let end = edge.end() else { return false }
        return type(of: start) == ObjectNode.self && type(of: end) == ObjectNode.self
    }
}

// MARK: - Validators

/// Validator for state diagrams.
public final class StateDiagramValidator: AbstractDiagramValidator {
    public init(_ diagram: Diagram) {
        precondition(diagram.diagramKind == .state)
        super.init(diagram,
                   nodeTypes: [ObjectIdentifier(StateNode.self), ObjectIdentifier(InitialStateNode.self),
                               ObjectIdentifier(FinalStateNode.self)],
                   edgeTypes: [ObjectIdentifier(StateTransitionEdge.self)],
                   constraints: [ConstraintMaxNumberOfEdgesOfGivenTypeBetweenNodes(2),
                                 ConstraintValidTransitionEdgeStartNode(),
                                 ConstraintValidTransitionEdgeEndNode()])
    }
}

/// Validator for object diagrams.
public final class ObjectDiagramValidator: AbstractDiagramValidator {
    public init(_ diagram: Diagram) {
        precondition(diagram.diagramKind == .object)
        super.init(diagram,
                   nodeTypes: [ObjectIdentifier(ObjectNode.self), ObjectIdentifier(FieldNode.self)],
                   edgeTypes: [ObjectIdentifier(ObjectReferenceEdge.self),
                               ObjectIdentifier(ObjectCollaborationEdge.self)],
                   constraints: [ConstraintValidReferenceEdge(),
                                 ConstraintValidCollaborationEdge(),
                                 ConstraintNoSelfEdgeForEdgeType(ObjectCollaborationEdge.self),
                                 ConstraintMaxNumberOfEdgesOfGivenTypeBetweenNodes(1),
                                 ConstraintNoDirectCyclesForEdgeType(ObjectCollaborationEdge.self)])
    }

    /// Root nodes must not be field nodes.
    public override func hasValidDiagramNodes() -> Bool {
        !diagram.rootNodes.contains { $0 is FieldNode }
    }
}

/// Validator for use case diagrams.
public final class UseCaseDiagramValidator: AbstractDiagramValidator {
    public init(_ diagram: Diagram) {
        precondition(diagram.diagramKind == .useCase)
        super.init(diagram,
                   nodeTypes: [ObjectIdentifier(ActorNode.self), ObjectIdentifier(UseCaseNode.self)],
                   edgeTypes: [ObjectIdentifier(UseCaseAssociationEdge.self),
                               ObjectIdentifier(UseCaseDependencyEdge.self),
                               ObjectIdentifier(UseCaseGeneralizationEdge.self)],
                   constraints: [ConstraintMaxNumberOfEdgesOfGivenTypeBetweenNodes(1),
                                 ConstraintNoSelfEdgeForEdgeType(UseCaseAssociationEdge.self),
                                 ConstraintNoSelfEdgeForEdgeType(UseCaseGeneralizationEdge.self),
                                 ConstraintNoSelfEdgeForEdgeType(UseCaseDependencyEdge.self)])
    }
}

extension DiagramValidatorFactory {
    /// The validator for the diagram's type, or `nil` if the type is not supported yet.
    public static func validator(for diagram: Diagram) -> (any DiagramValidator)? {
        switch diagram.diagramKind {
        case .class: ClassDiagramValidator(diagram)
        case .state: StateDiagramValidator(diagram)
        case .object: ObjectDiagramValidator(diagram)
        case .useCase: UseCaseDiagramValidator(diagram)
        case .sequence: SequenceDiagramValidator(diagram)
        }
    }
}
