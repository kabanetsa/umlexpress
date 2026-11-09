import Foundation
import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLPersistence
@testable import UMLRendering

/// Rendering and layout tests for sequence diagrams (M8, last diagram type).
final class SequenceDiagramTests: XCTestCase {

    private func fixture(_ name: String) throws -> Diagram {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/\(name).jet")
        return try DiagramCoding.decode(try Data(contentsOf: path))
    }

    /// Builds a small sequence diagram: client calls server.
    private func makeDiagram() -> (Diagram, ImplicitParameterNode, ImplicitParameterNode, CallNode) {
        let diagram = Diagram(kind: .sequence)
        let client = ImplicitParameterNode()
        client.setName(":Client")
        client.moveTo(Point(x: 0, y: 0))
        let server = ImplicitParameterNode()
        server.setName(":Server")
        server.moveTo(Point(x: 200, y: 0))
        diagram.addRootNode(client)
        diagram.addRootNode(server)

        let rootCall = CallNode()
        client.addChild(rootCall)
        let edge = CallEdge()
        edge.setMiddleLabel("call()")
        edge.connect(rootCall, CallNode())
        let target = edge.end() as! CallNode
        server.addChild(target)
        diagram.addEdge(edge)
        return (diagram, client, server, rootCall)
    }

    func testFactoryCreatesSequenceRenderer() {
        XCTAssertTrue(DiagramRendererFactory.renderer(for: Diagram(kind: .sequence))
            is SequenceDiagramRenderer)
    }

    func testRenderingSequenceDiagram() throws {
        let diagram = try fixture("testPersistenceService.sequence")
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let bounds = renderer.diagramBounds()
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)

        let context = SVGRenderingContext(viewport: bounds)
        renderer.drawDiagram(context)
        let svg = context.create()

        XCTAssertTrue(svg.contains("<rect "), "objects and call nodes are rectangles")
        XCTAssertTrue(svg.contains("stroke-dasharray"), "lifelines and returns are dotted")
        XCTAssertTrue(svg.contains("<path d=\"M "), "call edges are drawn")
    }

    func testLayoutAssignsYPositions() {
        let (diagram, client, server, rootCall) = makeDiagram()
        let renderer = SequenceDiagramRenderer(diagram: diagram)
        renderer.layout()

        // The root call is placed at the initial position.
        XCTAssertEqual(SequenceDiagramRenderer.initialYPosition, renderer.y(rootCall))
        // Its callee is below it.
        let callee = server.children.first as! CallNode
        XCTAssertGreaterThan(renderer.y(callee), renderer.y(rootCall))
        XCTAssertGreaterThan(renderer.maxY(callee), renderer.y(callee))

        // The lifeline of an object without a constructor call starts above the first call.
        XCTAssertEqual(SequenceDiagramRenderer.initialYPosition - SequenceDiagramRenderer.dropMin,
                       renderer.lifelineTop(client))
        XCTAssertEqual(SequenceDiagramRenderer.initialYPosition - SequenceDiagramRenderer.dropMin,
                       renderer.lifelineTop(server))
    }

    func testNestingDepth() {
        let (diagram, client, _, rootCall) = makeDiagram()
        // Add a self-call on the client: rootCall -> second call on the same object.
        let second = CallNode()
        client.addChild(second)
        let edge = CallEdge()
        edge.connect(rootCall, second)
        diagram.addEdge(edge)

        let renderer = SequenceDiagramRenderer(diagram: diagram)
        renderer.layout()
        XCTAssertEqual(0, renderer.nestingDepth(rootCall))
        XCTAssertEqual(1, renderer.nestingDepth(second), "a call on the same object nests one level")
        XCTAssertTrue(renderer.caller(second) === rootCall)
    }

    func testCallNodeBoundsUseLifelineAndDepth() {
        let (diagram, client, _, rootCall) = makeDiagram()
        let renderer = SequenceDiagramRenderer(diagram: diagram)
        renderer.layout()

        let bounds = renderer.bounds(of: rootCall)
        XCTAssertEqual(16, bounds.width)
        let centerX = renderer.centerX(client)
        // The bar is shifted left of the lifeline by the nesting shift (depth 0).
        XCTAssertEqual(centerX - 10, bounds.x)
    }

    func testImplicitParameterSelectionUsesTopRectangle() {
        let (diagram, client, _, _) = makeDiagram()
        let renderer = SequenceDiagramRenderer(diagram: diagram)
        renderer.layout()

        let top = ImplicitParameterNodeRenderer.topRectangle(client, renderer: renderer)
        XCTAssertTrue(renderer.selectableNodeAt(top.center()) === client)
        // As in the original, containment for an implicit parameter is the lifeline strip
        // (the x-range for the whole height), so a point far below still hits the object.
        XCTAssertTrue(renderer.selectableNodeAt(Point(x: top.center().x, y: top.maxY + 100)) === client)
        // A point outside the strip is not the object.
        XCTAssertFalse(renderer.selectableNodeAt(Point(x: top.maxX + 200, y: top.center().y)) === client)
    }

    func testSelfCallEdgeShape() {
        let (diagram, client, _, rootCall) = makeDiagram()
        let selfCall = CallEdge()
        let second = CallNode()
        client.addChild(second)
        selfCall.connect(rootCall, second)
        diagram.addEdge(selfCall)

        let renderer = SequenceDiagramRenderer(diagram: diagram)
        renderer.layout()
        let edgeRenderer = CallEdgeRenderer(renderer)
        XCTAssertTrue(selfCall.isSelfEdge)
        let points = edgeRenderer.points(selfCall)
        XCTAssertEqual(4, points.count, "a self call has a knee with four points")
        XCTAssertGreaterThan(points[2].x, points[0].x, "the knee goes to the right of the bar")
    }

    func testCallEdgeLabelIsRendered() {
        let (diagram, _, _, _) = makeDiagram()
        let renderer = SequenceDiagramRenderer(diagram: diagram)
        let context = SVGRenderingContext(viewport: Rectangle(x: -10, y: -10, width: 500, height: 400))
        renderer.drawDiagram(context)
        let svg = context.create()
        XCTAssertTrue(svg.contains(">call()</text>"))
    }

    func testConstructorCallDropsFurther() {
        let diagram = Diagram(kind: .sequence)
        let client = ImplicitParameterNode()
        client.setName(":Client")
        client.moveTo(Point(x: 0, y: 0))
        let created = ImplicitParameterNode()
        created.setName(":Created")
        created.moveTo(Point(x: 200, y: 0))
        diagram.addRootNode(client)
        diagram.addRootNode(created)

        let rootCall = CallNode()
        client.addChild(rootCall)
        let constructorEdge = ConstructorEdge()
        let target = CallNode()
        created.addChild(target)
        constructorEdge.connect(rootCall, target)
        diagram.addEdge(constructorEdge)

        let renderer = SequenceDiagramRenderer(diagram: diagram)
        renderer.layout()
        XCTAssertTrue(renderer.isConstructorCall(target))
        XCTAssertEqual(SequenceDiagramRenderer.initialYPosition + SequenceDiagramRenderer.dropConstructor,
                       renderer.y(target))
        // The lifeline of a constructed object starts just above its constructor call.
        XCTAssertEqual(renderer.y(target) - SequenceDiagramRenderer.constructorDrop,
                       renderer.lifelineTop(created))
    }

    func testHasEntryPoint() {
        let (diagram, _, _, _) = makeDiagram()
        XCTAssertTrue(SequenceDiagramRenderer(diagram: diagram).hasEntryPoint)
        let empty = Diagram(kind: .sequence)
        let parameter = ImplicitParameterNode()
        empty.addRootNode(parameter)
        XCTAssertFalse(SequenceDiagramRenderer(diagram: empty).hasEntryPoint)
    }

    func testWriteSequenceSample() throws {
        let diagram = try fixture("testPersistenceService.sequence")
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let context = SVGRenderingContext(viewport: renderer.diagramBounds())
        renderer.drawDiagram(context)
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Samples")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try context.create().write(to: directory.appendingPathComponent("fixture-sequence.svg"),
                                    atomically: true, encoding: .utf8)
    }
}
