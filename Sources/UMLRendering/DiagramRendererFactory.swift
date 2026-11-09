//
//  DiagramRendererFactory.swift
//  UMLExpress
//
//  Port of `DiagramType.newRendererInstanceFor` (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The factory lives in the rendering module so the model does not depend on rendering
//  (see §2.2 of the plan).
//

import UMLModel

/// Creates the renderer for a diagram type.
public enum DiagramRendererFactory {

    /// The renderer for the given diagram.
    public static func renderer(for diagram: Diagram) -> any DiagramViewRendererBridge {
        switch diagram.diagramKind {
        case .class: ClassDiagramRenderer(diagram: diagram)
        case .state: StateDiagramRenderer(diagram: diagram)
        case .object: ObjectDiagramRenderer(diagram: diagram)
        case .useCase: UseCaseDiagramRenderer(diagram: diagram)
        case .sequence: SequenceDiagramRenderer(diagram: diagram)
        }
    }
}
