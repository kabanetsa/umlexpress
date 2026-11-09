//
//  ClassDiagramRenderer.swift
//  UMLExpress
//
//  Port of the drawing part of org.jetuml.rendering.ClassDiagramRenderer
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The layout part lives in `ClassDiagramLayouter` (see M1.5); this class registers the
//  class-diagram renderers and wires the layouter to the stored edge renderer.
//

import Foundation
import UMLGeometry
import UMLModel

/// Computes the geometry of a class diagram and renders it on a rendering context.
public final class ClassDiagramRenderer: AbstractDiagramRenderer {

    /// The planned edge paths (shared with the layouter).
    public let storage = EdgeStorage()

    private lazy var layouter = ClassDiagramLayouter(diagram: diagram, bounds: self, storage: storage)

    /// Renderer for the edges whose path is planned by the layouter.
    private lazy var storedEdgeRenderer = StoredEdgeRenderer(self)

    public override init(diagram: Diagram) {
        precondition(diagram.diagramKind == .class, "ClassDiagramRenderer needs a class diagram")
        super.init(diagram: diagram)
        registerRenderers()
    }

    private func registerRenderers() {
        register(ClassNode.self, TypeNodeRenderer(self))
        register(InterfaceNode.self, InterfaceNodeRenderer(self))
        register(PackageNode.self, PackageNodeRenderer(self))
        register(PackageDescriptionNode.self, PackageDescriptionNodeRenderer(self))

        register(DependencyEdge.self, storedEdgeRenderer)
        register(AssociationEdge.self, storedEdgeRenderer)
        register(GeneralizationEdge.self, storedEdgeRenderer)
        register(AggregationEdge.self, storedEdgeRenderer)
    }

    // MARK: - Layout

    /// Plans the paths of all the edges of the diagram and stores them.
    public func layout() {
        layouter.layout()
    }

    public override func storedEdgePath(_ edge: any Edge) -> EdgePath? {
        storage.contains(edge) ? storage.edgePath(edge) : nil
    }

    // MARK: - Drawing

    /// Draws the nodes, plans the edge paths, then draws the edges.
    public override func drawEdges(_ context: any RenderingContext) {
        layout()
        for edge in diagram.edges {
            if EdgePriority.isStoredEdge(edge) {
                storedEdgeRenderer.draw(edge, context)
            } else {
                edgeRenderer(for: edge).draw(edge, context)
            }
        }
    }

    /// The bounds of the whole diagram, planning the paths first if needed.
    public override func diagramBounds() -> Rectangle {
        if storage.isEmpty {
            layout()
        }
        return super.diagramBounds()
    }

    /// The renderer for an edge: stored edges use the planned path, note connectors are
    /// drawn as straight dotted lines.
    public override func edgeRenderer(for edge: any Edge) -> any DiagramElementRenderer {
        EdgePriority.isStoredEdge(edge) ? storedEdgeRenderer : super.edgeRenderer(for: edge)
    }
}
