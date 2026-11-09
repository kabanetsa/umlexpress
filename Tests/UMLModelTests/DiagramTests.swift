import XCTest
@testable import UMLModel

/// Port of test/org/jetuml/diagram/DiagramTest.java (the parts that do not depend on
/// node types that are not ported yet).
final class DiagramTests: XCTestCase {

    private var node1 = StubNode()
    private var node2 = StubNode()
    private var node3 = StubNode()
    private var parent = StubParentNode()
    private var diagram = Diagram(kind: .class)

    override func setUp() {
        super.setUp()
        node1 = StubNode()
        node2 = StubNode()
        node3 = StubNode()
        parent = StubParentNode()
        diagram = Diagram(kind: .class)
    }

    func testContainsAsRootRootNode() {
        diagram.addRootNode(node1)
        XCTAssertTrue(diagram.containsAsRoot(node1))
    }

    func testContainsAsRootNonRootNode() {
        XCTAssertFalse(diagram.containsAsRoot(node1))
    }

    func testFileExtensions() {
        XCTAssertEqual(".class", Diagram(kind: .class).fileExtension)
        XCTAssertEqual(".sequence", Diagram(kind: .sequence).fileExtension)
        XCTAssertEqual(".state", Diagram(kind: .state).fileExtension)
        XCTAssertEqual(".object", Diagram(kind: .object).fileExtension)
        XCTAssertEqual(".usecase", Diagram(kind: .useCase).fileExtension)
    }

    func testName() {
        XCTAssertEqual("ClassDiagram", diagram.name)
        XCTAssertEqual(.class, diagram.diagramKind)
    }

    func testPlaceOnTopNonRootNode() {
        diagram.addRootNode(node2)
        diagram.placeOnTop(node1)
        XCTAssertEqual(1, diagram.rootNodes.count)
        XCTAssertTrue(diagram.rootNodes[0] === node2)
    }

    func testPlaceOnTopChildNodeWithParent() {
        parent.addChild(node2)
        node2.link(parent)
        parent.addChild(node3)
        node3.link(parent)

        diagram.addRootNode(parent)
        diagram.addRootNode(node1)
        diagram.placeOnTop(node2)

        XCTAssertEqual(2, diagram.rootNodes.count)
        XCTAssertTrue(diagram.rootNodes[0] === node1)
        XCTAssertTrue(diagram.rootNodes[1] === parent)
        // The moved child is now on top of all children.
        XCTAssertTrue(parent.children[1] === node2)
    }

    func testAllNodesSingleRoot() {
        diagram.addRootNode(node1)
        XCTAssertEqual(1, diagram.allNodes.count)
        XCTAssertTrue(diagram.allNodes[0] === node1)
    }

    func testAllNodesTwoChildlessRoots() {
        diagram.addRootNode(node1)
        diagram.addRootNode(node2)
        XCTAssertEqual(2, diagram.allNodes.count)
    }

    func testAllNodesThreeHierarchicalLevels() {
        let innerParent = StubParentNode()
        innerParent.addChild(node1)
        parent.addChild(innerParent)
        diagram.addRootNode(parent)

        let all = diagram.allNodes
        XCTAssertEqual(3, all.count)
        XCTAssertTrue(all[0] === parent)
        XCTAssertTrue(all[1] === innerParent)
        XCTAssertTrue(all[2] === node1)
    }

    func testEdgesConnectedToNoEdges() {
        diagram.addRootNode(node1)
        XCTAssertTrue(diagram.edgesConnectedTo(node1).isEmpty)
    }

    func testEdgesConnectedTo() {
        let edge = StubEdge()
        edge.connect(node1, node2)
        diagram.addRootNode(node1)
        diagram.addRootNode(node2)
        diagram.addEdge(edge)

        XCTAssertEqual(1, diagram.edgesConnectedTo(node1).count)
        XCTAssertEqual(1, diagram.edgesConnectedTo(node2).count)
        XCTAssertTrue(diagram.edgesConnectedTo(node1)[0] === edge)
    }

    func testEdgesToEmpty() {
        diagram.addRootNode(node1)
        XCTAssertTrue(diagram.edgesTo(node1, ofType: StubEdge.self).isEmpty)
    }

    func testEdgesToNodeSelection() {
        let edge = StubEdge()
        edge.connect(node1, node2)
        diagram.addRootNode(node1)
        diagram.addRootNode(node2)
        diagram.addEdge(edge)

        XCTAssertEqual(1, diagram.edgesTo(node2, ofType: StubEdge.self).count)
        XCTAssertTrue(diagram.edgesTo(node1, ofType: StubEdge.self).isEmpty)
    }

    func testEdgesToTypeSelection() {
        let edge = StubEdge()
        edge.connect(node1, node2)
        let other = OtherStubEdge()
        other.connect(node1, node2)
        diagram.addRootNode(node1)
        diagram.addRootNode(node2)
        diagram.addEdge(edge)
        diagram.addEdge(other)

        XCTAssertEqual(1, diagram.edgesTo(node2, ofType: StubEdge.self).count)
        XCTAssertTrue(diagram.edgesTo(node2, ofType: StubEdge.self)[0] === edge)
    }

    func testContains() {
        diagram.addRootNode(node1)
        parent.addChild(node2)
        diagram.addRootNode(parent)
        let edge = StubEdge()
        edge.connect(node1, node2)
        diagram.addEdge(edge)

        XCTAssertTrue(diagram.contains(node1))
        XCTAssertTrue(diagram.contains(parent))
        XCTAssertTrue(diagram.contains(node2))
        XCTAssertTrue(diagram.contains(edge))
        XCTAssertFalse(diagram.contains(node3))
    }

    func testAddAndRemoveEdgeKeepsOrder() {
        let first = StubEdge()
        first.connect(node1, node2)
        let second = OtherStubEdge()
        second.connect(node1, node2)
        diagram.addRootNode(node1)
        diagram.addRootNode(node2)
        diagram.addEdge(first)
        diagram.addEdge(second)

        XCTAssertEqual(0, diagram.indexOf(first))
        XCTAssertEqual(1, diagram.indexOf(second))

        diagram.removeEdge(first)
        XCTAssertEqual(1, diagram.edges.count)
        XCTAssertTrue(diagram.edges[0] === second)
    }

    func testDuplicate() {
        parent.addChild(node1)
        diagram.addRootNode(parent)
        diagram.addRootNode(node2)
        let edge = StubEdge()
        edge.connect(parent, node2)
        edge.setMiddleLabel("label")
        diagram.addEdge(edge)

        let copy = diagram.duplicate()

        XCTAssertEqual(2, copy.rootNodes.count)
        XCTAssertEqual(1, copy.edges.count)
        XCTAssertFalse(copy.rootNodes[0] === diagram.rootNodes[0], "nodes must be copied")
        XCTAssertEqual("label", (copy.edges[0] as? StubEdge)?.middleLabel)
        XCTAssertTrue(copy.edges[0].start() === copy.rootNodes[0], "edge must be reattached to the copy")
        XCTAssertTrue(copy.edges[0].end() === copy.rootNodes[1])
    }
}
