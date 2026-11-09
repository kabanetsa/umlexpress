//
//  StateObjectUseCaseDiagramRenderers.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.StateDiagramRenderer, ObjectDiagramRenderer and
//  UseCaseDiagramRenderer (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLModel

/// The renderer for state diagrams.
public final class StateDiagramRenderer: AbstractDiagramRenderer {

    public override init(diagram: Diagram) {
        precondition(diagram.diagramKind == .state)
        super.init(diagram: diagram)
        register(FinalStateNode.self, CircularStateNodeRenderer(self, final: true))
        register(InitialStateNode.self, CircularStateNodeRenderer(self, final: false))
        register(StateNode.self, StateNodeRenderer(self))
        register(StateTransitionEdge.self, StateTransitionEdgeRenderer(self))
    }
}

/// The renderer for object diagrams.
public final class ObjectDiagramRenderer: AbstractDiagramRenderer {

    public override init(diagram: Diagram) {
        precondition(diagram.diagramKind == .object)
        super.init(diagram: diagram)
        register(FieldNode.self, FieldNodeRenderer(self))
        register(ObjectNode.self, ObjectNodeRenderer(self))
        register(ObjectReferenceEdge.self, ObjectReferenceEdgeRenderer(self))
        register(ObjectCollaborationEdge.self, ObjectCollaborationEdgeRenderer(self))
    }
}

/// The renderer for use case diagrams.
public final class UseCaseDiagramRenderer: AbstractDiagramRenderer {

    public override init(diagram: Diagram) {
        precondition(diagram.diagramKind == .useCase)
        super.init(diagram: diagram)
        register(ActorNode.self, ActorNodeRenderer(self))
        register(UseCaseNode.self, UseCaseNodeRenderer(self))
        register(UseCaseAssociationEdge.self, UseCaseAssociationEdgeRenderer(self))
        register(UseCaseGeneralizationEdge.self, UseCaseGeneralizationEdgeRenderer(self))
        register(UseCaseDependencyEdge.self, UseCaseDependencyEdgeRenderer(self))
    }
}
