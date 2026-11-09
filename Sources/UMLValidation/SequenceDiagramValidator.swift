//
//  SequenceDiagramValidator.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.validator.SequenceDiagramValidator and its constraints
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLModel

/// A call or constructor edge (a subtype of `CallEdge`) can only be between call nodes.
public struct ConstraintCallEdgeBetweenCallNodes: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard edge is CallEdge else { return true }
        guard let start = edge.start(), let end = edge.end() else { return false }
        return Swift.type(of: start) == CallNode.self && Swift.type(of: end) == CallNode.self
    }
}

/// A return can only be between call nodes.
public struct ConstraintReturnEdgeBetweenCallNodes: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard edge is ReturnEdge else { return true }
        guard let start = edge.start(), let end = edge.end() else { return false }
        return Swift.type(of: start) == CallNode.self && Swift.type(of: end) == CallNode.self
    }
}

/// There can be at most one caller to a call node.
public struct ConstraintMaxOneCaller: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        diagram.allNodes
            .filter { $0 is CallNode }
            .allSatisfy { diagram.edgesTo($0, ofType: CallEdge.self).count <= 1 }
    }
}

/// A return edge must return to its caller, which must be a different node.
public struct ConstraintReturnsToCaller: EdgeConstraint {
    public init() {}
    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard Swift.type(of: edge) == ReturnEdge.self else { return true }
        guard let start = edge.start(), let end = edge.end() else { return false }
        let calls = diagram.edgesTo(start, ofType: CallEdge.self)
        guard calls.count == 1, let caller = calls[0].start() else { return false }
        guard end === caller else { return false }
        guard end.hasParent, start.hasParent else { return false }
        return !(end.getParent() === start.getParent())
    }
}

/// Validator for sequence diagrams.
public final class SequenceDiagramValidator: AbstractDiagramValidator {

    public init(_ diagram: Diagram) {
        precondition(diagram.diagramKind == .sequence)
        super.init(diagram,
                   nodeTypes: [ObjectIdentifier(ImplicitParameterNode.self),
                               ObjectIdentifier(CallNode.self)],
                   edgeTypes: [ObjectIdentifier(ConstructorEdge.self),
                               ObjectIdentifier(CallEdge.self),
                               ObjectIdentifier(ReturnEdge.self)],
                   constraints: [ConstraintMaxNumberOfEdgesOfGivenTypeBetweenNodes(1),
                                 ConstraintCallEdgeBetweenCallNodes(),
                                 ConstraintMaxOneCaller(),
                                 ConstraintReturnEdgeBetweenCallNodes(),
                                 ConstraintReturnsToCaller()])
    }

    /// Root nodes contain no call nodes, and there is at most one call node without a caller.
    public override func hasValidDiagramNodes() -> Bool {
        let noCallNodeRoot = diagram.rootNodes.allSatisfy { Swift.type(of: $0) != CallNode.self }
        let callNodes = diagram.allNodes.filter { $0 is CallNode }
        let orphanCalls = callNodes.filter { diagram.edgesTo($0, ofType: CallEdge.self).isEmpty }
        return noCallNodeRoot && orphanCalls.count <= 1
    }
}

extension DiagramValidatorFactory {
    /// The validator for the sequence diagram.
    public static func sequenceValidator(_ diagram: Diagram) -> any DiagramValidator {
        SequenceDiagramValidator(diagram)
    }
}
