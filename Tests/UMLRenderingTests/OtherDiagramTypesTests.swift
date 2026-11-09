import Foundation
import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLPersistence
@testable import UMLRendering

/// Rendering tests for the state, object and use case diagrams (M8).
final class OtherDiagramTypesTests: XCTestCase {

    private func fixture(_ name: String) throws -> Diagram {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/\(name).jet")
        return try DiagramCoding.decode(try Data(contentsOf: path))
    }

    // MARK: - Renderers from the factory

    func testFactoryCreatesRendererPerDiagramKind() {
        XCTAssertTrue(DiagramRendererFactory.renderer(for: Diagram(kind: .class)) is ClassDiagramRenderer)
        XCTAssertTrue(DiagramRendererFactory.renderer(for: Diagram(kind: .state)) is StateDiagramRenderer)
        XCTAssertTrue(DiagramRendererFactory.renderer(for: Diagram(kind: .object)) is ObjectDiagramRenderer)
        XCTAssertTrue(DiagramRendererFactory.renderer(for: Diagram(kind: .useCase)) is UseCaseDiagramRenderer)
    }

    // MARK: - State diagrams

    func testRenderStateDiagram() throws {
        let diagram = try fixture("testPersistenceService.state")
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let bounds = renderer.diagramBounds()
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)

        let context = SVGRenderingContext(viewport: bounds)
        renderer.drawDiagram(context)
        let svg = context.create()

        XCTAssertTrue(svg.hasPrefix("<svg viewBox="))
        // Initial/final states are drawn as ellipses.
        XCTAssertTrue(svg.contains("<ellipse "), "a circular state node is drawn")
        // States are rounded rectangles.
        XCTAssertTrue(svg.contains("rx=\"10\""), "a state node is a rounded rectangle")
        // Transitions are curved paths with a V arrow head.
        XCTAssertTrue(svg.contains("<path d=\"M "), "a transition path is drawn")
    }

    func testStateNodeGeometry() {
        let diagram = Diagram(kind: .state)
        let state = StateNode()
        state.setName("Idle")
        state.moveTo(Point(x: 10, y: 20))
        diagram.addRootNode(state)
        let renderer = StateDiagramRenderer(diagram: diagram)

        let bounds = renderer.bounds(of: state)
        XCTAssertGreaterThanOrEqual(bounds.width, 80)
        XCTAssertGreaterThanOrEqual(bounds.height, 60)
        XCTAssertEqual(Point(x: 10, y: 20), bounds.origin())
        // A state attaches on a rounded rectangle.
        let point = renderer.connectionPoint(of: state, Direction.north)
        XCTAssertEqual(bounds.center().x, point.x)
        XCTAssertEqual(bounds.y, point.y)
    }

    func testCircularStateNodeBounds() {
        let diagram = Diagram(kind: .state)
        let initial = InitialStateNode()
        initial.moveTo(Point(x: 5, y: 5))
        diagram.addRootNode(initial)
        let renderer = StateDiagramRenderer(diagram: diagram)
        XCTAssertEqual(Rectangle(x: 5, y: 5, width: 20, height: 20), renderer.bounds(of: initial))
    }

    /// A self-transition is drawn as an arc around the node corner.
    func testSelfTransitionUsesArc() {
        let diagram = Diagram(kind: .state)
        let state = StateNode()
        state.setName("S")
        state.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(state)
        let edge = StateTransitionEdge()
        edge.setMiddleLabel("loop")
        edge.connect(state, state)
        diagram.addEdge(edge)

        let renderer = StateDiagramRenderer(diagram: diagram)
        let context = SVGRenderingContext(viewport: Rectangle(x: 0, y: 0, width: 300, height: 300))
        renderer.drawDiagram(context)
        let svg = context.create()
        XCTAssertTrue(svg.contains(" A 20 20 "), "the self-transition is an arc of radius 20")
        XCTAssertTrue(svg.contains(">loop</text>"))
    }

    // MARK: - Object diagrams

    /// Writes SVG renderings of the state, object and use case fixtures for inspection.
    func testWriteSamplesForNewDiagramTypes() throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Samples")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, file) in [("state", "testPersistenceService.state"),
                             ("object", "testPersistenceService.object"),
                             ("usecase", "testPersistenceService.usecase")] {
            let diagram = try fixture(file)
            let renderer = DiagramRendererFactory.renderer(for: diagram)
            let context = SVGRenderingContext(viewport: renderer.diagramBounds())
            renderer.drawDiagram(context)
            try context.create().write(to: directory.appendingPathComponent("fixture-\(name).svg"),
                                        atomically: true, encoding: .utf8)
        }
    }

    func testRenderObjectDiagram() throws {
        let diagram = try fixture("testPersistenceService.object")
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let context = SVGRenderingContext(viewport: renderer.diagramBounds())
        renderer.drawDiagram(context)
        let svg = context.create()

        XCTAssertTrue(svg.contains("<rect "), "objects are rectangles")
        XCTAssertTrue(svg.contains(" = "), "fields are rendered as 'name = value'")
        XCTAssertTrue(svg.contains("<path d=\"M "), "reference edges are curved paths")
    }

    func testFieldNodeInsideObject() {
        let diagram = Diagram(kind: .object)
        let object = ObjectNode()
        object.setName(":Client")
        object.moveTo(Point(x: 0, y: 0))
        let field = FieldNode()
        field.setName("id")
        field.setValue("42")
        object.addChild(field)
        diagram.addRootNode(object)

        let renderer = ObjectDiagramRenderer(diagram: diagram)
        let objectBounds = renderer.bounds(of: object)
        let fieldBounds = renderer.bounds(of: field)
        XCTAssertTrue(objectBounds.contains(fieldBounds), "the field is inside the object box")
        XCTAssertGreaterThan(objectBounds.height, 60, "the object grows to fit its fields")

        let context = SVGRenderingContext(viewport: Rectangle(x: -10, y: -10, width: 300, height: 300))
        renderer.drawDiagram(context)
        let svg = context.create()
        XCTAssertTrue(svg.contains(">:Client</text>"))
        XCTAssertTrue(svg.contains(">id</text>"))
        XCTAssertTrue(svg.contains(">42</text>"))
    }

    func testReferenceEdgeIsSOrCShaped() {
        let diagram = Diagram(kind: .object)
        let object = ObjectNode()
        object.setName(":A")
        object.moveTo(Point(x: 0, y: 0))
        let field = FieldNode()
        field.setName("ref")
        field.setValue("")
        object.addChild(field)
        diagram.addRootNode(object)

        let renderer = ObjectDiagramRenderer(diagram: diagram)
        let rendererEdge = ObjectReferenceEdgeRenderer(renderer)
        let edge = ObjectReferenceEdge()
        edge.connect(field, object)
        diagram.addEdge(edge)

        let path = rendererEdge.shape(of: edge)
        XCTAssertEqual(5, path.count, "an S- or C-shape has five path commands")
    }

    // MARK: - Use case diagrams

    func testRenderUseCaseDiagram() throws {
        let diagram = try fixture("testPersistenceService.usecase")
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let context = SVGRenderingContext(viewport: renderer.diagramBounds())
        renderer.drawDiagram(context)
        let svg = context.create()

        XCTAssertTrue(svg.contains("<ellipse "), "use cases are ellipses")
        XCTAssertTrue(svg.contains("Q "), "the actor is drawn with quadratic curves")
        XCTAssertTrue(svg.contains("<path d=\"M "), "edges are drawn")
    }

    func testUseCaseNodeGeometry() {
        let diagram = Diagram(kind: .useCase)
        let useCase = UseCaseNode()
        useCase.setName("Buy")
        useCase.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(useCase)
        let renderer = UseCaseDiagramRenderer(diagram: diagram)
        let bounds = renderer.bounds(of: useCase)
        XCTAssertGreaterThanOrEqual(bounds.width, 110)
        XCTAssertGreaterThanOrEqual(bounds.height, 40)
        // The connection point is on the ellipse, not on the bounding box corner.
        let point = renderer.connectionPoint(of: useCase, Direction.fromAngle(45))
        XCTAssertTrue(bounds.contains(point))
    }

    func testActorBoundsIncludeName() {
        let diagram = Diagram(kind: .useCase)
        let actor = ActorNode()
        actor.moveTo(Point(x: 40, y: 40))
        diagram.addRootNode(actor)
        let renderer = UseCaseDiagramRenderer(diagram: diagram)
        let bounds = renderer.bounds(of: actor)
        // The actor figure plus the name below it.
        XCTAssertGreaterThan(bounds.height, ActorNodeRenderer.height,
                             "the bounds include the name below the figure")
        XCTAssertGreaterThanOrEqual(bounds.width, ActorNodeRenderer.width)
        XCTAssertEqual(Point(x: 40, y: 40), bounds.origin())
    }

    func testUseCaseDependencyLabel() {
        let diagram = Diagram(kind: .useCase)
        let first = UseCaseNode()
        first.setName("A")
        first.moveTo(Point(x: 0, y: 0))
        let second = UseCaseNode()
        second.setName("B")
        second.moveTo(Point(x: 300, y: 0))
        diagram.addRootNode(first)
        diagram.addRootNode(second)

        let edge = UseCaseDependencyEdge(.include)
        edge.connect(first, second)
        diagram.addEdge(edge)

        let renderer = UseCaseDiagramRenderer(diagram: diagram)
        let context = SVGRenderingContext(viewport: Rectangle(x: -10, y: -10, width: 500, height: 200))
        renderer.drawDiagram(context)
        let svg = context.create()
        XCTAssertTrue(svg.contains("\u{00AB}include\u{00BB}"), "the dependency shows its stereotype label")
        XCTAssertTrue(svg.contains("stroke-dasharray"), "the dependency is dotted")
    }
}
