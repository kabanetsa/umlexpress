import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLOperations
@testable import UMLRendering

/// Builders for the state, object and use case diagrams (M8).
final class OtherBuildersTests: XCTestCase {

    func testFactoryReturnsBuilderPerKind() {
        XCTAssertTrue(DiagramBuilderFactory.builder(for: Diagram(kind: .class)) is ClassDiagramBuilder)
        XCTAssertTrue(DiagramBuilderFactory.builder(for: Diagram(kind: .state)) is StateDiagramBuilder)
        XCTAssertTrue(DiagramBuilderFactory.builder(for: Diagram(kind: .object)) is ObjectDiagramBuilder)
        XCTAssertTrue(DiagramBuilderFactory.builder(for: Diagram(kind: .useCase)) is UseCaseDiagramBuilder)
    }

    func testFieldIsAddedToTheObjectUnderThePoint() {
        let diagram = Diagram(kind: .object)
        let object = ObjectNode()
        object.setName(":A")
        object.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(object)
        let builder = ObjectDiagramBuilder(diagram)

        let field = FieldNode()
        let operation = builder.createAddNodeOperation(field, Point(x: 20, y: 20))
        operation.execute()

        XCTAssertEqual(1, object.children.count, "the field becomes a child of the object")
        XCTAssertTrue(object.children[0] === field)
        XCTAssertFalse(diagram.containsAsRoot(field))

        operation.undo()
        XCTAssertTrue(object.children.isEmpty)
    }

    func testFieldOutsideObjectsBecomesRootNode() {
        let diagram = Diagram(kind: .object)
        let builder = ObjectDiagramBuilder(diagram)
        let field = FieldNode()
        let operation = builder.createAddNodeOperation(field, Point(x: 500, y: 500))
        operation.execute()
        XCTAssertTrue(diagram.containsAsRoot(field), "without a container the field stays a root node")
    }

    func testReferenceEdgeFromFieldClearsItsValue() {
        let diagram = Diagram(kind: .object)
        let object = ObjectNode()
        object.setName(":A")
        object.moveTo(Point(x: 0, y: 0))
        let field = FieldNode()
        field.setName("ref")
        field.setValue("42")
        object.addChild(field)
        let other = ObjectNode()
        other.setName(":B")
        other.moveTo(Point(x: 300, y: 0))
        diagram.addRootNode(object)
        diagram.addRootNode(other)

        let builder = ObjectDiagramBuilder(diagram)
        let renderer = builder.renderer
        let fieldCenter = renderer.boundsOf(field).center()
        let otherCenter = renderer.boundsOf(other).center()
        let edge = ObjectReferenceEdge()
        let operation = builder.createAddEdgeOperation(edge, fieldCenter, otherCenter)
        operation.execute()

        XCTAssertEqual("", field.value, "the field value is cleared when a reference is drawn from it")
        operation.undo()
        XCTAssertEqual("42", field.value)
    }

    func testStateAndUseCaseBuildersCreateNodes() {
        for kind in [DiagramKind.state, .useCase] {
            let diagram = Diagram(kind: kind)
            let builder = DiagramBuilderFactory.builder(for: diagram)
            let node: any Node = kind == .state ? StateNode() : UseCaseNode()
            let operation = builder.createAddNodeOperation(node, Point(x: 50, y: 60))
            operation.execute()
            XCTAssertEqual(1, diagram.rootNodes.count)
            operation.undo()
            XCTAssertTrue(diagram.rootNodes.isEmpty)
        }
    }
}

/// Builder for sequence diagrams.
final class SequenceBuilderTests: XCTestCase {

    private func makeDiagram() -> (Diagram, ImplicitParameterNode, ImplicitParameterNode) {
        let diagram = Diagram(kind: .sequence)
        let client = ImplicitParameterNode()
        client.setName(":Client")
        client.moveTo(Point(x: 0, y: 0))
        let server = ImplicitParameterNode()
        server.setName(":Server")
        server.moveTo(Point(x: 200, y: 0))
        diagram.addRootNode(client)
        diagram.addRootNode(server)
        return (diagram, client, server)
    }

    func testFactoryCreatesSequenceBuilder() {
        XCTAssertTrue(DiagramBuilderFactory.builder(for: Diagram(kind: .sequence)) is SequenceDiagramBuilder)
    }

    /// Drawing a call from one lifeline to another creates the two call nodes.
    func testCallEdgeCreatesCallNodes() {
        let (diagram, client, server) = makeDiagram()
        let builder = SequenceDiagramBuilder(diagram)
        let renderer = builder.renderer

        // Points below the top rectangles of the objects: a plain call, not a constructor.
        let clientPoint = Point(x: renderer.boundsOf(client).center().x,
                                y: renderer.boundsOf(client).maxY - 20)
        let serverPoint = Point(x: renderer.boundsOf(server).center().x,
                                y: renderer.boundsOf(server).maxY - 20)

        let edge = CallEdge()
        let operation = builder.createAddEdgeOperation(edge, clientPoint, serverPoint)
        operation.execute()

        XCTAssertEqual(1, diagram.edges.count)
        XCTAssertEqual(1, client.children.count, "a call node is created on the caller")
        XCTAssertEqual(1, server.children.count, "a call node is created on the callee")
        XCTAssertTrue(edge.start() === client.children[0])
        XCTAssertTrue(edge.end() === server.children[0])

        operation.undo()
        XCTAssertTrue(diagram.edges.isEmpty)
        XCTAssertTrue(client.children.isEmpty)
        XCTAssertTrue(server.children.isEmpty)
    }

    /// Drawing onto the top rectangle of an empty object creates a constructor call.
    func testConstructorCallIsCreated() {
        let (diagram, client, server) = makeDiagram()
        let builder = SequenceDiagramBuilder(diagram)
        let renderer = builder.renderer
        let clientPoint = Point(x: renderer.boundsOf(client).center().x,
                                y: renderer.boundsOf(client).maxY - 20)
        // The top rectangle of the server object.
        let serverTopRectangle = ImplicitParameterNodeRenderer.topRectangle(
            server, renderer: renderer as! SequenceDiagramRenderer)
        let serverTop = serverTopRectangle.center()

        let operation = builder.createAddEdgeOperation(CallEdge(), clientPoint, serverTop)
        operation.execute()

        XCTAssertEqual(1, diagram.edges.count)
        XCTAssertTrue(diagram.edges[0] is ConstructorEdge, "a call onto an empty object is a constructor")
    }

    /// A call node dropped on a lifeline becomes a child of that object.
    func testCallNodeAddedToLifeline() {
        let (diagram, client, _) = makeDiagram()
        let builder = SequenceDiagramBuilder(diagram)
        let renderer = builder.renderer
        // A point inside the lifeline, below the top rectangle.
        let bounds = renderer.boundsOf(client)
        let point = Point(x: bounds.center().x, y: bounds.maxY - 10)

        let callNode = CallNode()
        let operation = builder.createAddNodeOperation(callNode, point)
        operation.execute()
        XCTAssertEqual(1, client.children.count)
        operation.undo()
        XCTAssertTrue(client.children.isEmpty)
    }
}
