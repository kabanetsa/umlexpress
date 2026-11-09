//
//  ClassDiagramValidator.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.validator.ClassDiagramValidator
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLModel

/// Validator for class diagrams.
public final class ClassDiagramValidator: AbstractDiagramValidator {

    public init(_ diagram: Diagram) {
        precondition(diagram.diagramKind == .class)
        super.init(
            diagram,
            nodeTypes: [
                ObjectIdentifier(ClassNode.self),
                ObjectIdentifier(InterfaceNode.self),
                ObjectIdentifier(PackageNode.self),
                ObjectIdentifier(PackageDescriptionNode.self),
            ],
            edgeTypes: [
                ObjectIdentifier(DependencyEdge.self),
                ObjectIdentifier(GeneralizationEdge.self),
                ObjectIdentifier(AssociationEdge.self),
                ObjectIdentifier(AggregationEdge.self),
            ],
            constraints: [
                ConstraintMaxNumberOfEdgesOfGivenTypeBetweenNodes(1),
                ConstraintNoSelfEdgeForEdgeType(GeneralizationEdge.self),
                ConstraintNoSelfEdgeForEdgeType(DependencyEdge.self),
                ConstraintNoDirectCyclesForEdgeType(DependencyEdge.self),
                ConstraintNoDirectCyclesForEdgeType(GeneralizationEdge.self),
                ConstraintNoDirectCyclesForEdgeType(AggregationEdge.self),
                ConstraintNoDirectCyclesForEdgeType(AssociationEdge.self),
                ConstraintNoCombinedAssociationAggregation(),
            ])
    }
}
