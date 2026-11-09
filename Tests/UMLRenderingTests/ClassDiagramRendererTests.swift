import Foundation
import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLRendering

/// Tests for the node renderers, the stored edge renderer and the end-to-end SVG
/// rendering of a class diagram.
final class ClassDiagramRendererTests: XCTestCase {

    private var renderer: ClassDiagramRenderer!
    private var figure: ClassNode!
    private var group: ClassNode!
    private var diagram: Diagram!

    override func setUp() {
        super.setUp()
        figure = ClassNode()
        figure.setName("Figure")
        figure.moveTo(Point(x: 0, y: 0))
        group = ClassNode()
        group.setName("Group")
        group.moveTo(Point(x: 0, y: 120))
        diagram = Diagram(kind: .class)
        diagram.addRootNode(figure)
        diagram.addRootNode(group)
        renderer = ClassDiagramRenderer(diagram: diagram)
    }

    // MARK: - Node renderers

    func testTypeNodeDefaultBounds() {
        let bounds = renderer.bounds(of: figure)
        XCTAssertGreaterThanOrEqual(bounds.width, TypeNodeRenderer.defaultWidth)
        XCTAssertEqual(TypeNodeRenderer.defaultHeight, bounds.height,
                       "a class without attributes or methods is the default height")
        XCTAssertEqual(0, bounds.x)
        XCTAssertEqual(0, bounds.y)
    }

    func testTypeNodeBoundsGrowWithAttributesAndMethods() {
        figure.setAttributes("id:int")
        figure.setMethods("draw():void")
        let bounds = renderer.bounds(of: figure)
        XCTAssertGreaterThan(bounds.height, TypeNodeRenderer.defaultHeight)
    }

    func testInterfaceNameIncludesStereotype() {
        let interface = InterfaceNode()
        interface.setName("Renderer")
        interface.moveTo(Point(x: 200, y: 0))
        diagram.addRootNode(interface)

        XCTAssertEqual("\u{00AB}interface\u{00BB}\nRenderer",
                       InterfaceNodeRenderer(renderer).nameText(interface))
    }

    func testNoteNodeBounds() {
        let note = NoteNode()
        note.setName("a note")
        note.moveTo(Point(x: 300, y: 0))
        let bounds = renderer.nodeRenderer(for: note).bounds(note)
        XCTAssertGreaterThanOrEqual(bounds.width, NoteNodeRenderer.defaultWidth)
        XCTAssertGreaterThanOrEqual(bounds.height, NoteNodeRenderer.defaultHeight)
    }

    // MARK: - End-to-end SVG

    func testRenderClassDiagramToSVG() {
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(group, figure)
        diagram.addEdge(edge)

        let bounds = renderer.diagramBounds()
        let context = SVGRenderingContext(viewport: bounds)
        renderer.draw(context)
        let svg = context.create()

        XCTAssertTrue(svg.hasPrefix("<svg viewBox="))
        XCTAssertTrue(svg.hasSuffix("</g></svg>"))
        // Two class shapes plus their drop shadows.
        XCTAssertEqual(4, svg.components(separatedBy: "<rect ").count - 1)
        // Two class shapes and the unfilled (white) triangle arrow head.
        XCTAssertEqual(3, svg.components(separatedBy: "stroke=\"black\" fill=\"white\"/>").count - 1)
        // Names are rendered as text
        XCTAssertTrue(svg.contains(">Figure</text>"))
        XCTAssertTrue(svg.contains(">Group</text>"))
        // The edge contributes a polyline path and a triangle arrow head
        XCTAssertTrue(svg.contains("<path d=\"M "), "the edge path must be drawn")
        // A generalization is drawn solid: no dash pattern is emitted.
        XCTAssertFalse(svg.contains("stroke-dasharray"))
    }

    /// Writes a sample SVG next to the sources so that the output can be inspected and
    /// compared with a JetUML export by hand. Not an assertion — a debugging aid.
    func testWriteSampleSVG() throws {
        figure.setAttributes("elements:Set")
        figure.setMethods("draw():void")
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(group, figure)
        diagram.addEdge(edge)

        let bounds = renderer.diagramBounds()
        let context = SVGRenderingContext(viewport: bounds)
        renderer.draw(context)
        let svg = context.create()

        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Samples")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try svg.write(to: directory.appendingPathComponent("classDiagram.svg"),
                      atomically: true, encoding: .utf8)
    }

    func testGeneralizationIsSolidAndDependencyIsDotted() {
        let generalization = GeneralizationEdge(.inheritance)
        generalization.connect(group, figure)
        let dependency = DependencyEdge()
        dependency.connect(group, figure)
        diagram.addEdge(generalization)
        diagram.addEdge(dependency)

        renderer.layout()
        XCTAssertEqual(.solid, StoredEdgeRenderer.lineStyle(generalization))
        XCTAssertEqual(.dotted, StoredEdgeRenderer.lineStyle(dependency))
        XCTAssertEqual(.dotted, StoredEdgeRenderer.lineStyle(GeneralizationEdge(.implementation)))
    }

    func testArrowHeads() {
        let aggregation = AggregationEdge(.aggregation)
        XCTAssertEqual(.diamond, StoredEdgeRenderer.arrowStart(aggregation))
        XCTAssertEqual(.none, StoredEdgeRenderer.arrowEnd(aggregation))

        let composition = AggregationEdge(.composition)
        XCTAssertEqual(.blackDiamond, StoredEdgeRenderer.arrowStart(composition))

        let generalization = GeneralizationEdge(.inheritance)
        XCTAssertEqual(.none, StoredEdgeRenderer.arrowStart(generalization))
        XCTAssertEqual(.triangle, StoredEdgeRenderer.arrowEnd(generalization))

        let association = AssociationEdge()
        XCTAssertEqual(.none, StoredEdgeRenderer.arrowStart(association))
        XCTAssertEqual(.none, StoredEdgeRenderer.arrowEnd(association))
        association.setDirectionality(.unidirectional)
        XCTAssertEqual(.v, StoredEdgeRenderer.arrowEnd(association))
        association.setDirectionality(.bidirectional)
        XCTAssertEqual(.v, StoredEdgeRenderer.arrowStart(association))
        XCTAssertEqual(.v, StoredEdgeRenderer.arrowEnd(association))

        let dependency = DependencyEdge()
        XCTAssertEqual(.v, StoredEdgeRenderer.arrowEnd(dependency))
        dependency.setDirectionality(.bidirectional)
        XCTAssertEqual(.v, StoredEdgeRenderer.arrowStart(dependency))
    }

    func testLabelsDoNotBreakRendering() {
        let association = AssociationEdge()
        association.setStartLabel("1")
        association.setMiddleLabel("elements")
        association.setEndLabel("*")
        association.connect(group, figure)
        diagram.addEdge(association)

        let bounds = renderer.diagramBounds()
        let context = SVGRenderingContext(viewport: bounds)
        renderer.draw(context)
        let svg = context.create()

        XCTAssertTrue(svg.contains(">elements</text>"))
        XCTAssertTrue(svg.contains(">1</text>"))
        XCTAssertTrue(svg.contains(">*</text>"))
    }

    func testStoredPathIsAvailableAfterLayout() {
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(group, figure)
        diagram.addEdge(edge)

        XCTAssertNil(renderer.storedEdgePath(edge))
        renderer.layout()
        let path = renderer.storedEdgePath(edge)
        XCTAssertNotNil(path)
        XCTAssertGreaterThanOrEqual(path?.size ?? 0, 2)
    }
}

final class EdgeRenderingHelpersTests: XCTestCase {

    func testWrapString() {
        XCTAssertEqual("a b", AbstractEdgeRenderer.wrapString("a b", 15))
        XCTAssertEqual("aa bb\ncc", AbstractEdgeRenderer.wrapString("aa bb cc", 5))
        XCTAssertEqual("abc", AbstractEdgeRenderer.wrapString("abc", 3))
    }

    func testArrowHeadPath() {
        // A horizontal axis pointing right: the triangle sits at the end point.
        let axis = Line(x1: 0, y1: 0, x2: 100, y2: 0)
        let path = ArrowHeadRenderer.path(.triangle, axis)
        XCTAssertEqual(4, path.count)
        XCTAssertEqual(.move(to: Point(x: 100, y: 0)), path[0])
        XCTAssertEqual(4, path.count)
        XCTAssertTrue(ArrowHeadRenderer.path(.none, axis).isEmpty)

        let bounds = ArrowHeadRenderer.bounds(.triangle, axis)
        XCTAssertEqual(100, bounds.maxX)
        XCTAssertGreaterThan(bounds.height, 0)
    }

    func testPolylineContains() {
        let path: [PathCommand] = [.move(to: Point(x: 0, y: 0)), .line(to: Point(x: 100, y: 0))]
        XCTAssertTrue(AbstractEdgeRenderer.polylineContains(path, Point(x: 50, y: 1), tolerance: 3))
        XCTAssertFalse(AbstractEdgeRenderer.polylineContains(path, Point(x: 50, y: 10), tolerance: 3))
    }

    func testPolylineBounds() {
        let path: [PathCommand] = [.move(to: Point(x: 10, y: 20)), .line(to: Point(x: 40, y: 5))]
        XCTAssertEqual(Rectangle(x: 10, y: 5, width: 30, height: 15),
                       AbstractEdgeRenderer.polylineBounds(path))
    }
}
