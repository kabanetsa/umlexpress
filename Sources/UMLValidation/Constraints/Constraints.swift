//
//  Constraints.swift
//  UMLExpress
//
//  Port of the edge constraints in org.jetuml.diagram.validator.constraints
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry
import UMLModel

/// Validates that a note edge is semantically correct: either from a note node to a
/// point node, or from any other node to a note node.
public struct ConstraintValidNoteEdge: EdgeConstraint {

    public init() {}

    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard type(of: edge) == NoteEdge.self else {
            return true
        }
        guard let start = edge.start(), let end = edge.end() else {
            return false
        }
        if type(of: end) == PointNode.self {
            return type(of: start) == NoteNode.self
        }
        return type(of: start) != PointNode.self && type(of: start) != NoteNode.self
            && type(of: end) == NoteNode.self
    }
}

/// Validates that only note edges can point to point nodes.
public struct ConstraintNoEdgeToPointExceptNoteEdge: EdgeConstraint {

    public init() {}

    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard type(of: edge) != NoteEdge.self else {
            return true
        }
        guard let start = edge.start(), let end = edge.end() else {
            return false
        }
        return type(of: start) != PointNode.self && type(of: end) != PointNode.self
    }
}

/// Validates that no edge except note edges can connect to a note node.
public struct ConstraintNoEdgeToNoteExceptNoteEdge: EdgeConstraint {

    public init() {}

    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard type(of: edge) != NoteEdge.self else {
            return true
        }
        guard let start = edge.start(), let end = edge.end() else {
            return false
        }
        return type(of: start) != NoteNode.self && type(of: end) != NoteNode.self
    }
}

/// There can't be an edge of the given type between the same node.
public struct ConstraintNoSelfEdgeForEdgeType: EdgeConstraint {

    private let edgeType: ObjectIdentifier

    public init(_ edgeType: AnyClass) {
        self.edgeType = ObjectIdentifier(edgeType)
    }

    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard ObjectIdentifier(type(of: edge)) == edgeType else {
            return true
        }
        guard let start = edge.start(), let end = edge.end() else {
            return false
        }
        return !(start === end)
    }
}

/// There can't be more than a given number of edges of the same type between two nodes.
public struct ConstraintMaxNumberOfEdgesOfGivenTypeBetweenNodes: EdgeConstraint {

    private let maxNumberOfEdges: Int

    public init(_ maxNumberOfEdges: Int) {
        self.maxNumberOfEdges = maxNumberOfEdges
    }

    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        let edgeType = ObjectIdentifier(type(of: edge))
        let count = diagram.edges.filter { other in
            guard ObjectIdentifier(type(of: other)) == edgeType else { return false }
            guard let start = other.start(), let end = other.end() else { return false }
            guard let edgeStart = edge.start(), let edgeEnd = edge.end() else { return false }
            return start === edgeStart && end === edgeEnd
        }.count
        return count <= maxNumberOfEdges
    }
}

/// There can't be two edges of a given type, one in each direction, between two
/// different nodes.
public struct ConstraintNoDirectCyclesForEdgeType: EdgeConstraint {

    private let edgeType: ObjectIdentifier

    public init(_ edgeType: AnyClass) {
        self.edgeType = ObjectIdentifier(edgeType)
    }

    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        guard ObjectIdentifier(type(of: edge)) == edgeType else {
            return true
        }
        guard let edgeStart = edge.start(), let edgeEnd = edge.end(), !(edgeStart === edgeEnd) else {
            return true
        }
        let reversed = diagram.edgesConnectedTo(edgeStart).filter { other in
            guard ObjectIdentifier(type(of: other)) == edgeType else { return false }
            guard let start = other.start(), let end = other.end() else { return false }
            return end === edgeStart && start === edgeEnd
        }
        return reversed.isEmpty
    }
}

/// There can't be both an association and an aggregation edge between two nodes.
public struct ConstraintNoCombinedAssociationAggregation: EdgeConstraint {

    public init() {}

    public func satisfied(_ edge: any Edge, _ diagram: Diagram) -> Bool {
        let count = diagram.edges.filter { other in
            ConstraintNoCombinedAssociationAggregation.isAssociationOrAggregation(other)
                && ConstraintNoCombinedAssociationAggregation.isBetweenSameNodes(other, edge)
        }.count
        return count <= 1
    }

    private static func isAssociationOrAggregation(_ edge: any Edge) -> Bool {
        let type = ObjectIdentifier(type(of: edge))
        return type == ObjectIdentifier(AssociationEdge.self) || type == ObjectIdentifier(AggregationEdge.self)
    }

    /// Irrespective of direction.
    private static func isBetweenSameNodes(_ edge1: any Edge, _ edge2: any Edge) -> Bool {
        guard let start1 = edge1.start(), let end1 = edge1.end(),
              let start2 = edge2.start(), let end2 = edge2.end() else {
            return false
        }
        return (start1 === start2 && end1 === end2) || (start1 === end2 && end1 === start2)
    }
}
