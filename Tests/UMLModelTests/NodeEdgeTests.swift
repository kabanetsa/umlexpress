import XCTest
@testable import UMLGeometry
@testable import UMLModel

/// Port of test/org/jetuml/diagram/nodes/ClassNodeTest.java and
/// test/org/jetuml/diagram/nodes/InterfaceNodeTest.java, plus property-order checks.
final class ClassNodeTests: XCTestCase {

    func testDefaults() {
        let node = ClassNode()
        XCTAssertEqual("", node.name)
        XCTAssertEqual("", node.attributes)
        XCTAssertEqual("", node.methods)
        XCTAssertEqual(Point(x: 0, y: 0), node.position)
        XCTAssertFalse(node.hasParent)
        XCTAssertFalse(node.requiresParent)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testSetName() {
        let node = ClassNode()
        node.setName("A")
        XCTAssertEqual("A", node.name)
    }

    func testSetMethodsAndAttributes() {
        let node = ClassNode()
        node.setMethods("m():void")
        node.setAttributes("a:int")
        XCTAssertEqual("m():void", node.methods)
        XCTAssertEqual("a:int", node.attributes)
    }

    /// ClassNode inserts `attributes` at index 1, so the visible order is
    /// name, attributes, methods.
    func testPropertyOrder() {
        let node = ClassNode()
        XCTAssertEqual([.name, .attributes, .methods], node.properties.map(\.name))
    }

    func testPropertiesAreBound() {
        let node = ClassNode()
        node.properties.get(.name).set("Client")
        node.properties.get(.attributes).set("id:int")
        node.properties.get(.methods).set("draw():void")

        XCTAssertEqual("Client", node.name)
        XCTAssertEqual("id:int", node.attributes)
        XCTAssertEqual("draw():void", node.methods)
        XCTAssertEqual("Client", node.properties.string(.name))
    }

    func testPositionAndTranslate() {
        let node = ClassNode()
        node.moveTo(Point(x: 30, y: 40))
        XCTAssertEqual(Point(x: 30, y: 40), node.position)
        node.translate(5, -10)
        XCTAssertEqual(Point(x: 35, y: 30), node.position)
    }

    func testCopyCopiesState() {
        let node = ClassNode()
        node.moveTo(Point(x: 10, y: 20))
        node.setName("Server")
        node.setAttributes("id:int")
        node.setMethods("m()")

        let copy = node.copy()
        XCTAssertFalse(copy === node)
        XCTAssertEqual(node.position, copy.position)
        XCTAssertEqual("Server", copy.name)
        XCTAssertEqual("id:int", copy.attributes)
        XCTAssertEqual("m()", copy.methods)

        // Independent state and independent properties object
        copy.setName("Other")
        XCTAssertEqual("Server", node.name)
        XCTAssertFalse(copy.properties === node.properties)
    }

    func testLinkAndUnlink() {
        let node = ClassNode()
        let package = PackageNode()
        node.link(package)
        XCTAssertTrue(node.hasParent)
        XCTAssertTrue(node.getParent() === package)
        node.unlink()
        XCTAssertFalse(node.hasParent)
    }
}

final class InterfaceNodeTests: XCTestCase {

    func testDefaults() {
        let node = InterfaceNode()
        XCTAssertEqual("", node.name)
        XCTAssertEqual("", node.methods)
        XCTAssertEqual("", node.attributes)
    }

    func testSetName() {
        let node = InterfaceNode()
        node.setName("Figure")
        XCTAssertEqual("Figure", node.name)
    }

    /// An interface node has no attributes property, unlike a class node.
    func testPropertyOrder() {
        let node = InterfaceNode()
        XCTAssertEqual([.name, .methods], node.properties.map(\.name))
    }
}

final class NoteNodeTests: XCTestCase {

    func testNameIsText() {
        let note = NoteNode()
        note.setName("a note")
        XCTAssertEqual("a note", note.name)
        XCTAssertEqual([.name], note.properties.map(\.name))
    }
}

final class LabelEdgeTests: XCTestCase {

    func testMiddleLabel() {
        let edge = StubEdge()
        XCTAssertEqual("", edge.middleLabel)
        edge.setMiddleLabel("elements")
        XCTAssertEqual("elements", edge.middleLabel)
        XCTAssertEqual("elements", edge.properties.string(.middleLabel))
    }

    func testThreeLabelOrder() {
        let edge = ThreeLabelEdgeStub()
        XCTAssertEqual([.startLabel, .middleLabel, .endLabel], edge.properties.map(\.name))
    }

    func testThreeLabelBinding() {
        let edge = ThreeLabelEdgeStub()
        edge.setStartLabel("1")
        edge.setMiddleLabel("2")
        edge.setEndLabel("3")
        XCTAssertEqual("1", edge.properties.string(.startLabel))
        XCTAssertEqual("2", edge.properties.string(.middleLabel))
        XCTAssertEqual("3", edge.properties.string(.endLabel))
    }

    func testConnection() {
        let start = StubNode()
        let end = StubNode()
        let edge = StubEdge()
        XCTAssertNil(edge.start())
        XCTAssertNil(edge.end())
        edge.connect(start, end)
        XCTAssertTrue(edge.start() === start)
        XCTAssertTrue(edge.end() === end)
    }

    func testCopyIsShallowForNodes() {
        let start = StubNode()
        let end = StubNode()
        let edge = StubEdge()
        edge.connect(start, end)
        edge.setMiddleLabel("L")

        let copy = edge.copy()
        XCTAssertTrue(copy.start() === start, "nodes are shallow-copied")
        XCTAssertTrue(copy.end() === end)
        XCTAssertEqual("L", copy.middleLabel)
        XCTAssertFalse(copy === edge)
    }
}

/// Concrete three-label edge used by the tests (the original instantiates
/// `AssociationEdge`/`AggregationEdge`, which are not ported yet).
final class ThreeLabelEdgeStub: ThreeLabelEdge {
    public required init() { super.init() }
    public override func copy() -> ThreeLabelEdgeStub {
        let duplicate = ThreeLabelEdgeStub()
        duplicate.setStartLabel(startLabel)
        duplicate.setMiddleLabel(middleLabel)
        duplicate.setEndLabel(endLabel)
        return duplicate
    }
}
