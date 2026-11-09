//
//  OtherDiagramBuilders.swift
//  UMLExpress
//
//  Port of org.jetuml.diagram.builder.StateDiagramBuilder, UseCaseDiagramBuilder and
//  ObjectDiagramBuilder (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry
import UMLModel
import UMLRendering

/// A builder for state diagrams: the default behaviour is sufficient.
public final class StateDiagramBuilder: DiagramBuilder {
    public override init(_ renderer: any DiagramViewRenderer) {
        precondition(renderer.diagramModel.diagramKind == .state)
        super.init(renderer)
    }

    public convenience init(_ diagram: Diagram) {
        self.init(StateDiagramRenderer(diagram: diagram))
    }
}

/// A builder for use case diagrams: the default behaviour is sufficient.
public final class UseCaseDiagramBuilder: DiagramBuilder {
    public override init(_ renderer: any DiagramViewRenderer) {
        precondition(renderer.diagramModel.diagramKind == .useCase)
        super.init(renderer)
    }

    public convenience init(_ diagram: Diagram) {
        self.init(UseCaseDiagramRenderer(diagram: diagram))
    }
}

/// A builder for object diagrams: fields are added to the object under the cursor, and
/// creating a reference edge from a field clears its value.
public final class ObjectDiagramBuilder: DiagramBuilder {

    public override init(_ renderer: any DiagramViewRenderer) {
        precondition(renderer.diagramModel.diagramKind == .object)
        super.init(renderer)
    }

    public convenience init(_ diagram: Diagram) {
        self.init(ObjectDiagramRenderer(diagram: diagram))
    }

    public override func createAddNodeOperation(_ node: any Node,
                                                _ requestedPosition: Point) -> any DiagramOperation {
        if let field = node as? FieldNode, let object = findObject(field, requestedPosition) {
            return SimpleOperation({ object.addChild(node) }, reverse: { object.removeChild(node) })
        }
        return super.createAddNodeOperation(node, requestedPosition)
    }

    /// The object that should contain the field: the field's current parent, or the last
    /// object under the point.
    private func findObject(_ field: FieldNode, _ point: Point) -> ObjectNode? {
        var candidates: [ObjectNode] = []
        for node in diagram.rootNodes {
            guard let object = node as? ObjectNode, object !== field else {
                continue
            }
            if field.hasParent, field.getParent() === object {
                return object
            }
            if renderer.contains(object, point), object.allowsAsChild(field) {
                candidates.append(object)
            }
        }
        // The last candidate is a simple heuristic for the top-most node.
        return candidates.last
    }

    public override func completeEdgeAdditionOperation(_ operation: CompoundOperation, _ edge: any Edge,
                                                       _ startNode: any Node, _ endNode: any Node,
                                                       _ start: Point, _ end: Point) {
        super.completeEdgeAdditionOperation(operation, edge, startNode, endNode, start, end)
        if let field = startNode as? FieldNode {
            let oldValue = field.value
            operation.add(SimpleOperation({ field.setValue("") },
                                          reverse: { field.setValue(oldValue) }))
        }
    }
}

/// Creates the builder for a diagram type (port of `DiagramType.newBuilderInstanceFor`).
///
/// The implementation lives in the per-type builder files, e.g.
/// `SequenceDiagramBuilder.swift`.
public enum DiagramBuilderFactory {}
