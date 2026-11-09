//
//  DiagramViewRendererBridge.swift
//  UMLExpress
//
//  The builder (in `UMLOperations`) needs a few rendering services. Defining the
//  protocol here, next to the renderer, keeps the dependency direction sane: the
//  operations module depends on rendering, not the other way round.
//

import CoreGraphics
import UMLGeometry
import UMLModel

/// The rendering services a diagram builder needs.
public protocol DiagramViewRendererBridge: AnyObject {
    /// The diagram wrapped by the renderer.
    var diagramModel: Diagram { get }
    /// The bounds of an element.
    func boundsOf(_ element: any DiagramElement) -> Rectangle
    /// The default size of a node of this type.
    func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension
    /// The node at a point, if any.
    func nodeAt(_ point: Point) -> (any Node)?
    /// True if the element contains the point.
    func contains(_ element: any DiagramElement, _ point: Point) -> Bool
    /// The bounds of a package node.
    func packageBounds(_ node: PackageNode) -> Rectangle
    /// The edge at a point, if any.
    func edgeAt(_ point: Point) -> (any Edge)?
    /// The selectable node at a point, if any.
    func selectableNodeAt(_ point: Point) -> (any Node)?
    /// The bounds of the elements, extended to include their parents.
    func boundsIncludingParents(_ elements: [any DiagramElement]) -> Rectangle
    /// The bounds of the elements, excluding their parents.
    func boundsNotIncludingParents(_ elements: [any DiagramElement]) -> Rectangle
    /// Draws the whole diagram.
    func drawDiagram(_ context: any RenderingContext)
    /// The bounding box of the whole diagram.
    func diagramBounds() -> Rectangle
    /// Renders the palette icon of an element, or nil when the element has none.
    func icon(of element: any DiagramElement) -> CGImage?
    /// The points where an edge leaves its end nodes, or nil when it is not connected.
    func edgeEndPoints(_ edge: any Edge) -> (Point, Point)?
}
