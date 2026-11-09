import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLPersistence

/// Port of test/org/jetuml/persistence/PersistenceServiceTest.java: the reference files
/// are the ones shipped with JetUML 3.10 (JSON schema 3.0).
final class DiagramCodingTests: XCTestCase {

    // MARK: - Fixtures

    private func fixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "jet",
                                          subdirectory: "Fixtures") else {
            XCTFail("missing fixture \(name)")
            return Data()
        }
        return try Data(contentsOf: url)
    }

    func testDecodeClassDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.class"))
        XCTAssertEqual(.class, diagram.diagramKind)
        XCTAssertEqual(8, diagram.allNodes.count)
        XCTAssertEqual(6, diagram.edges.count)
        XCTAssertEqual("ClassDiagram", diagram.name)
    }

    func testDecodeObjectDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.object"))
        XCTAssertEqual(.object, diagram.diagramKind)
        XCTAssertFalse(diagram.allNodes.isEmpty)
        XCTAssertFalse(diagram.edges.isEmpty)
    }

    func testDecodeSequenceDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.sequence"))
        XCTAssertEqual(.sequence, diagram.diagramKind)
        XCTAssertFalse(diagram.allNodes.isEmpty)
    }

    func testDecodeStateDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.state"))
        XCTAssertEqual(.state, diagram.diagramKind)
        XCTAssertFalse(diagram.allNodes.isEmpty)
    }

    func testDecodeUseCaseDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.usecase"))
        XCTAssertEqual(.useCase, diagram.diagramKind)
        XCTAssertFalse(diagram.allNodes.isEmpty)
    }

    func testDecodePerformanceDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixture("performanceDiagram.class"))
        XCTAssertEqual(.class, diagram.diagramKind)
        XCTAssertEqual(13, diagram.allNodes.count)
        XCTAssertEqual(11, diagram.edges.count)
    }

    // MARK: - Content details

    func testDecodedNodePropertiesAndPositions() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.class"))

        let classes = diagram.allNodes.compactMap { $0 as? ClassNode }
        XCTAssertEqual(4, classes.count)

        let named = classes.first { $0.name == "Node5" }
        XCTAssertNotNil(named)
        XCTAssertEqual("attribute1", named?.attributes)
        XCTAssertEqual("method1", named?.methods)
        XCTAssertEqual(Point(x: 200, y: 280), named?.position)

        let interfaces = diagram.allNodes.compactMap { $0 as? InterfaceNode }
        XCTAssertEqual(1, interfaces.count)
        XCTAssertEqual("Node1", interfaces.first?.name)
    }

    func testDecodedChildren() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.class"))
        let packages = diagram.allNodes.compactMap { $0 as? PackageNode }
        XCTAssertEqual(1, packages.count)
        let package = try XCTUnwrap(packages.first)
        XCTAssertEqual("Node7", package.name)
        XCTAssertEqual(1, package.children.count)
        XCTAssertEqual("Node2", (package.children[0] as? ClassNode)?.name)
        XCTAssertTrue(package.children[0].hasParent)
        // Only the package is a root node.
        XCTAssertTrue(diagram.containsAsRoot(package))
        XCTAssertFalse(diagram.containsAsRoot(package.children[0]))
    }

    func testDecodedEdgeProperties() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.class"))

        let aggregations = diagram.edges.compactMap { $0 as? AggregationEdge }
        XCTAssertEqual(2, aggregations.count)
        let composition = aggregations.first { $0.type == .composition }
        XCTAssertEqual("e5", composition?.middleLabel)
        XCTAssertEqual("", composition?.startLabel)
        XCTAssertEqual("", composition?.endLabel)

        let label = aggregations.first { $0.type == .aggregation }
        XCTAssertEqual("1", label?.startLabel)
        XCTAssertEqual("e4", label?.middleLabel)
        XCTAssertEqual("*", label?.endLabel)

        let generalizations = diagram.edges.compactMap { $0 as? GeneralizationEdge }
        XCTAssertEqual(2, generalizations.count)
        XCTAssertEqual(1, generalizations.filter { $0.type == .implementation }.count)
        XCTAssertEqual(1, generalizations.filter { $0.type == .inheritance }.count)

        let dependencies = diagram.edges.compactMap { $0 as? DependencyEdge }
        XCTAssertEqual(1, dependencies.count)
        XCTAssertEqual(.unidirectional, dependencies.first?.directionality)
        XCTAssertEqual("e1", dependencies.first?.middleLabel)
    }

    // MARK: - Round trip

    func testRoundTripPreservesStructure() throws {
        for name in ["testPersistenceService.class", "testPersistenceService.object",
                     "testPersistenceService.sequence", "testPersistenceService.state",
                     "testPersistenceService.usecase", "testPersistenceService2.class"] {
            let original = try DiagramCoding.decode(try fixture(name))
            let encoded = try DiagramCoding.encode(original)
            let decoded = try DiagramCoding.decode(encoded)

            XCTAssertEqual(original.diagramKind, decoded.diagramKind, "diagram kind of \(name)")
            XCTAssertEqual(original.allNodes.count, decoded.allNodes.count, "node count of \(name)")
            XCTAssertEqual(original.edges.count, decoded.edges.count, "edge count of \(name)")
            XCTAssertEqual(original.allNodes.map(\.position), decoded.allNodes.map(\.position),
                           "positions of \(name)")
            XCTAssertEqual(original.allNodes.map { String(describing: type(of: $0)) },
                           decoded.allNodes.map { String(describing: type(of: $0)) },
                           "node types of \(name)")
            XCTAssertEqual(original.edges.map { String(describing: type(of: $0)) },
                           decoded.edges.map { String(describing: type(of: $0)) },
                           "edge types of \(name)")
        }
    }

    func testEncodeIsStableAndCompact() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.class"))
        let first = try DiagramCoding.encode(diagram)
        let second = try DiagramCoding.encode(diagram)
        XCTAssertEqual(first, second, "encoding must be deterministic")

        let text = String(decoding: first, as: UTF8.self)
        XCTAssertFalse(text.contains("\n")) // one line, as in JetUML
        XCTAssertTrue(text.hasPrefix("{\"version\":\"3.10\""))
        XCTAssertTrue(text.contains("\"diagram\":\"ClassDiagram\""))
        XCTAssertTrue(text.contains("\"nodes\":["))
        XCTAssertTrue(text.contains("\"edges\":["))
    }

    func testEncodeChildIdsMatchNodeIds() throws {
        let diagram = try DiagramCoding.decode(try fixture("testPersistenceService.class"))
        let text = String(decoding: try DiagramCoding.encode(diagram), as: UTF8.self)
        // The package holds exactly one child: the node with id 7 in the fixture.
        XCTAssertTrue(text.contains("\"children\":["), "children must be encoded")
    }

    // MARK: - Errors

    func testSyntacticError() {
        let data = Data("this is not json".utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case .syntactic = error as? DiagramPersistenceError else {
                return XCTFail("expected a syntactic error, got \(error)")
            }
        }
    }

    func testRootMustBeObject() {
        let data = Data("[1,2,3]".utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            XCTAssertEqual(.structural("The root of a diagram file must be a JSON object"),
                           error as? DiagramPersistenceError)
        }
    }

    func testInvalidDiagramType() {
        let data = Data(#"{"version":"3.10","diagram":"NopeDiagram","nodes":[],"edges":[]}"#.utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error")
            }
            XCTAssertTrue(message.contains("Invalid diagram type"))
        }
    }

    func testUnknownNodeType() {
        let data = Data(#"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[{"id":0,"type":"NopeNode","x":0,"y":0}],"edges":[]}
        """#.utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error")
            }
            XCTAssertTrue(message.contains("Unknown node type"))
        }
    }

    func testMissingProperty() {
        // A ClassNode without the required "name" property.
        let data = Data(#"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[{"id":0,"type":"ClassNode","x":0,"y":0,
        "attributes":"","methods":""}],"edges":[]}
        """#.utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error")
            }
            XCTAssertTrue(message.contains("name"))
        }
    }

    func testInvalidChildId() {
        let data = Data(#"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[
        {"id":0,"type":"PackageNode","name":"P","x":0,"y":0,"children":[99]}],"edges":[]}
        """#.utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error")
            }
            XCTAssertTrue(message.contains("Invalid node id"))
        }
    }

    func testInvalidParentChildRelation() {
        let data = Data(#"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[
        {"id":0,"type":"PackageNode","name":"P","x":0,"y":0,"children":[1]},
        {"id":1,"type":"NoteNode","name":"N","x":0,"y":0}],"edges":[]}
        """#.utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error")
            }
            XCTAssertTrue(message.contains("Invalid parent-child relation"))
        }
    }

    func testEdgeWithMissingVertex() {
        let data = Data(#"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[
        {"id":0,"type":"ClassNode","name":"A","x":0,"y":0,"attributes":"","methods":""}],
        "edges":[{"type":"NoteEdge","start":0,"end":5}]}
        """#.utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error")
            }
            XCTAssertTrue(message.contains("edge vertex"))
        }
    }

    func testInvalidVersion() {
        let data = Data(#"{"version":"3.x","diagram":"ClassDiagram","nodes":[],"edges":[]}"#.utf8)
        XCTAssertThrowsError(try DiagramCoding.decode(data)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error")
            }
            XCTAssertTrue(message.contains("version"))
        }
    }

    // MARK: - Factory

    func testFactoryCoversAllNodeTypes() {
        let nodeTypes = ["ClassNode", "InterfaceNode", "PackageNode", "PackageDescriptionNode",
                         "NoteNode", "StateNode", "InitialStateNode", "FinalStateNode", "ActorNode",
                         "UseCaseNode", "ObjectNode", "FieldNode", "ImplicitParameterNode",
                         "CallNode", "PointNode"]
        for type in nodeTypes {
            XCTAssertNotNil(DiagramElementFactory.makeNode(type), "missing node factory for \(type)")
        }
        XCTAssertNil(DiagramElementFactory.makeNode("Nope"))
    }

    func testFactoryCoversAllEdgeTypes() {
        let edgeTypes = ["AggregationEdge", "AssociationEdge", "DependencyEdge", "GeneralizationEdge",
                         "NoteEdge", "CallEdge", "ConstructorEdge", "ReturnEdge",
                         "ObjectReferenceEdge", "ObjectCollaborationEdge", "StateTransitionEdge",
                         "UseCaseAssociationEdge", "UseCaseDependencyEdge", "UseCaseGeneralizationEdge"]
        for type in edgeTypes {
            XCTAssertNotNil(DiagramElementFactory.makeEdge(type), "missing edge factory for \(type)")
        }
        XCTAssertNil(DiagramElementFactory.makeEdge("Nope"))
    }
}

/// Semantic validation is now applied when decoding, as `PersistenceService.read` does.
final class DiagramCodingValidationTests: XCTestCase {

    private func decode(_ json: String) throws -> Diagram {
        try DiagramCoding.decode(Data(json.utf8))
    }

    func testSemanticallyInvalidDiagramIsRejected() {
        // Two generalizations in opposite directions form a direct cycle.
        let json = #"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[
        {"id":0,"type":"ClassNode","name":"A","x":0,"y":0,"attributes":"","methods":""},
        {"id":1,"type":"ClassNode","name":"B","x":0,"y":100,"attributes":"","methods":""}],
        "edges":[{"type":"GeneralizationEdge","start":0,"end":1,"Generalization Type":"Inheritance"},
        {"type":"GeneralizationEdge","start":1,"end":0,"Generalization Type":"Inheritance"}]}
        """#
        XCTAssertThrowsError(try decode(json)) { error in
            guard case let .semantic(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a semantic error, got \(error)")
            }
            XCTAssertEqual("Diagram has invalid semantics", message)
        }
    }

    func testStructurallyInvalidDiagramIsRejected() {
        // A point node that is not connected to any edge.
        let json = #"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[
        {"id":0,"type":"PointNode","x":10,"y":10}],"edges":[]}
        """#
        XCTAssertThrowsError(try decode(json)) { error in
            guard case let .structural(message) = error as? DiagramPersistenceError else {
                return XCTFail("expected a structural error, got \(error)")
            }
            XCTAssertEqual("Diagram has invalid structure", message)
        }
    }

    func testValidDiagramPasses() throws {
        let json = #"""
        {"version":"3.10","diagram":"ClassDiagram","nodes":[
        {"id":0,"type":"ClassNode","name":"A","x":0,"y":0,"attributes":"","methods":""},
        {"id":1,"type":"ClassNode","name":"B","x":0,"y":100,"attributes":"","methods":""}],
        "edges":[{"type":"GeneralizationEdge","start":0,"end":1,"Generalization Type":"Inheritance"}]}
        """#
        let diagram = try decode(json)
        XCTAssertEqual(2, diagram.allNodes.count)
    }
}
