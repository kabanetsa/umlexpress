import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLRendering

/// Supplies fixed bounds per node, standing in for node renderers in the spike.
final class FixedBoundsProvider: NodeBoundsProvider {

    private var boundsByNode: [ObjectIdentifier: Rectangle] = [:]

    func set(_ node: any Node, _ bounds: Rectangle) {
        boundsByNode[ObjectIdentifier(node)] = bounds
    }

    func bounds(of node: any Node) -> Rectangle {
        guard let bounds = boundsByNode[ObjectIdentifier(node)] else {
            preconditionFailure("no bounds registered for node \(node)")
        }
        return bounds
    }
}

/// The M1.5 spike: verifies that the ported edge-routing algorithm produces the same
/// paths as the Java heuristics for the core scenarios.
final class ClassDiagramLayouterTests: XCTestCase {

    private var top = ClassNode()
    private var bottomLeft = ClassNode()
    private var bottomRight = ClassNode()
    private var diagram = Diagram(kind: .class)
    private var bounds = FixedBoundsProvider()

    override func setUp() {
        super.setUp()
        top = ClassNode()
        bottomLeft = ClassNode()
        bottomRight = ClassNode()
        diagram = Diagram(kind: .class)
        bounds = FixedBoundsProvider()
        bounds.set(top, Rectangle(x: 0, y: 0, width: 60, height: 40))
        bounds.set(bottomLeft, Rectangle(x: 0, y: 100, width: 60, height: 40))
        bounds.set(bottomRight, Rectangle(x: 100, y: 100, width: 60, height: 40))
        diagram.addRootNode(top)
        diagram.addRootNode(bottomLeft)
        diagram.addRootNode(bottomRight)
    }

    private func layouter() -> ClassDiagramLayouter {
        ClassDiagramLayouter(diagram: diagram, bounds: bounds)
    }

    // MARK: - Single segmented edge

    /// A generalization between two vertically stacked nodes: the middle segment sits
    /// halfway between the two connection points (y = 70).
    func testSingleGeneralization() {
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(bottomLeft, top)
        diagram.addEdge(edge)

        let layouter = layouter()
        layouter.layout()

        let path = layouter.storedEdgePath(edge)
        XCTAssertNotNil(path)
        XCTAssertEqual(4, path?.size)
        XCTAssertEqual(Point(x: 30, y: 100), path?.startPoint)
        XCTAssertEqual(Point(x: 30, y: 70), path?.point(at: 1))
        XCTAssertEqual(Point(x: 30, y: 70), path?.point(at: 2))
        XCTAssertEqual(Point(x: 30, y: 40), path?.endPoint)
    }

    /// Two edges ending at the same node merge into a shared end point but keep their
    /// own start points.
    func testMergedEndEdges() {
        let first = GeneralizationEdge(.inheritance)
        first.connect(bottomLeft, top)
        let second = GeneralizationEdge(.inheritance)
        second.connect(bottomRight, top)
        diagram.addEdge(first)
        diagram.addEdge(second)

        let layouter = layouter()
        layouter.layout()

        let firstPath = layouter.storedEdgePath(first)
        let secondPath = layouter.storedEdgePath(second)
        XCTAssertEqual(Point(x: 30, y: 100), firstPath?.startPoint)
        XCTAssertEqual(Point(x: 130, y: 100), secondPath?.startPoint)
        // Both end at the same connection point on the bottom face of the top node.
        XCTAssertEqual(Point(x: 30, y: 40), firstPath?.endPoint)
        XCTAssertEqual(Point(x: 30, y: 40), secondPath?.endPoint)
        // ... and share the middle line.
        XCTAssertEqual(firstPath?.point(at: 1).y, secondPath?.point(at: 1).y)
        XCTAssertEqual(70, firstPath?.point(at: 1).y)
    }

    /// A dependency edge is a single straight segment between the two faces.
    func testDependencyEdgeIsStraight() {
        let edge = DependencyEdge()
        edge.connect(bottomLeft, top)
        diagram.addEdge(edge)

        let layouter = layouter()
        layouter.layout()

        let path = layouter.storedEdgePath(edge)
        XCTAssertEqual(2, path?.size)
        XCTAssertEqual(Point(x: 30, y: 100), path?.startPoint)
        XCTAssertEqual(Point(x: 30, y: 40), path?.endPoint)
    }

    /// A self-edge gets a 5-point path around the node corner.
    func testSelfEdge() {
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(top, top)
        diagram.addEdge(edge)

        let layouter = layouter()
        layouter.layout()

        let path = layouter.storedEdgePath(edge)
        XCTAssertEqual(5, path?.size)
        XCTAssertEqual(Point(x: 40, y: 0), path?.startPoint)
        XCTAssertEqual(Point(x: 40, y: -20), path?.point(at: 1))
        XCTAssertEqual(Point(x: 80, y: -20), path?.point(at: 2))
        XCTAssertEqual(Point(x: 80, y: 20), path?.point(at: 3))
        XCTAssertEqual(Point(x: 60, y: 20), path?.endPoint)
    }

    /// Two edges between the same pair of nodes cannot merge (different labels), so the
    /// second one offsets its middle segment by 10 px.
    func testSharedNodeEdgesAreOffset() {
        let first = AssociationEdge()
        first.setStartLabel("1")
        first.setEndLabel("a")
        first.connect(bottomLeft, top)
        let second = AssociationEdge()
        second.setStartLabel("2")
        second.setEndLabel("b")
        second.connect(bottomLeft, top)
        diagram.addEdge(first)
        diagram.addEdge(second)

        let layouter = layouter()
        layouter.layout()

        let firstPath = layouter.storedEdgePath(first)
        let secondPath = layouter.storedEdgePath(second)
        XCTAssertNotNil(firstPath)
        XCTAssertNotNil(secondPath)
        XCTAssertEqual(70, firstPath?.point(at: 1).y)
        XCTAssertEqual(60, secondPath?.point(at: 1).y, "the second edge must be offset by 10px")
    }

    /// Every segment of a planned path is axis-aligned.
    func testPathsAreOrthogonal() {
        let generalization = GeneralizationEdge(.inheritance)
        generalization.connect(bottomRight, top)
        let dependency = DependencyEdge()
        dependency.connect(bottomLeft, bottomRight)
        let selfEdge = GeneralizationEdge(.implementation)
        selfEdge.connect(top, top)
        diagram.addEdge(generalization)
        diagram.addEdge(dependency)
        diagram.addEdge(selfEdge)

        let layouter = layouter()
        layouter.layout()

        for edge in diagram.edges {
            guard let path = layouter.storedEdgePath(edge) else {
                return XCTFail("no path for \(edge)")
            }
            let points = path.allPoints
            for index in 0..<(points.count - 1) {
                let current = points[index]
                let next = points[index + 1]
                XCTAssertTrue(current.x == next.x || current.y == next.y,
                              "segment \(index) of \(edge) is not orthogonal")
            }
        }
    }
}

/// Tests for the supporting enumerations.
final class RenderingGeometryTests: XCTestCase {

    func testSide() {
        XCTAssertTrue(Side.top.isHorizontal)
        XCTAssertTrue(Side.bottom.isHorizontal)
        XCTAssertFalse(Side.right.isHorizontal)
        XCTAssertTrue(Side.left.isVertical)
        XCTAssertEqual(Side.bottom, Side.top.mirrored())
        XCTAssertEqual(Side.left, Side.right.mirrored())
        XCTAssertEqual(Side.top, Side.bottom.mirrored())
        XCTAssertEqual(Side.right, Side.left.mirrored())

        let rectangle = Rectangle(x: 10, y: 20, width: 60, height: 40)
        XCTAssertEqual(Line(x1: 10, y1: 20, x2: 70, y2: 20), Side.top.line(in: rectangle))
        XCTAssertEqual(Line(x1: 10, y1: 60, x2: 70, y2: 60), Side.bottom.line(in: rectangle))
        XCTAssertEqual(Line(x1: 70, y1: 20, x2: 70, y2: 60), Side.right.line(in: rectangle))
        XCTAssertEqual(Line(x1: 10, y1: 20, x2: 10, y2: 60), Side.left.line(in: rectangle))
    }

    func testNodeCornerIndexes() {
        XCTAssertEqual(.plusThree, NodeCorner.horizontalIndex(.topRight))
        XCTAssertEqual(.plusThree, NodeCorner.horizontalIndex(.bottomRight))
        XCTAssertEqual(.minusThree, NodeCorner.horizontalIndex(.topLeft))
        XCTAssertEqual(.minusThree, NodeCorner.horizontalIndex(.bottomLeft))
        XCTAssertEqual(.minusOne, NodeCorner.verticalIndex(.topLeft))
        XCTAssertEqual(.minusOne, NodeCorner.verticalIndex(.topRight))
        XCTAssertEqual(.plusOne, NodeCorner.verticalIndex(.bottomLeft))
        XCTAssertEqual(.plusOne, NodeCorner.verticalIndex(.bottomRight))
        XCTAssertEqual(Direction.north, NodeCorner.horizontalSide(.topLeft))
        XCTAssertEqual(Direction.south, NodeCorner.horizontalSide(.bottomLeft))
        XCTAssertEqual(Direction.east, NodeCorner.verticalSide(.bottomRight))
        XCTAssertEqual(Direction.west, NodeCorner.verticalSide(.bottomLeft))
    }

    func testNodeIndexPointOnFace() {
        let face = Line(x1: 0, y1: 100, x2: 60, y2: 100)
        // Spacing on a 60px north/south face is 10, centred on the snapped midpoint.
        XCTAssertEqual(Point(x: 30, y: 100), NodeIndex.zero.point(on: face, side: .top))
        XCTAssertEqual(Point(x: 40, y: 100), NodeIndex.plusOne.point(on: face, side: .top))
        XCTAssertEqual(Point(x: 20, y: 100), NodeIndex.minusOne.point(on: face, side: .top))
        XCTAssertEqual(Point(x: 70, y: 100), NodeIndex.plusFour.point(on: face, side: .top))
    }

    func testEdgePriority() {
        let inheritance = GeneralizationEdge(.inheritance)
        let implementation = GeneralizationEdge(.implementation)
        let aggregation = AggregationEdge(.aggregation)
        let composition = AggregationEdge(.composition)
        let association = AssociationEdge()
        let dependency = DependencyEdge()
        let note = NoteEdge()

        XCTAssertEqual(.inheritance, EdgePriority.priority(of: inheritance))
        XCTAssertEqual(.implementation, EdgePriority.priority(of: implementation))
        XCTAssertEqual(.aggregation, EdgePriority.priority(of: aggregation))
        XCTAssertEqual(.composition, EdgePriority.priority(of: composition))
        XCTAssertEqual(.association, EdgePriority.priority(of: association))
        XCTAssertEqual(.dependency, EdgePriority.priority(of: dependency))
        XCTAssertEqual(.other, EdgePriority.priority(of: note))

        let node = ClassNode()
        let selfEdge = GeneralizationEdge(.inheritance)
        selfEdge.connect(node, node)
        XCTAssertEqual(.selfEdge, EdgePriority.priority(of: selfEdge))

        XCTAssertTrue(EdgePriority.isSegmented(.inheritance))
        XCTAssertTrue(EdgePriority.isSegmented(.association))
        XCTAssertFalse(EdgePriority.isSegmented(.dependency))
        XCTAssertTrue(EdgePriority.isSegmentedEdge(inheritance))
        XCTAssertFalse(EdgePriority.isSegmentedEdge(dependency))
        XCTAssertTrue(EdgePriority.isStoredEdge(inheritance))
        XCTAssertFalse(EdgePriority.isStoredEdge(note))
    }

    func testEdgePath() {
        let path = EdgePath(Point(x: 0, y: 0), Point(x: 10, y: 10), Point(x: 20, y: 20))
        XCTAssertEqual(3, path.size)
        XCTAssertEqual(Point(x: 0, y: 0), path.startPoint)
        XCTAssertEqual(Point(x: 20, y: 20), path.endPoint)
        XCTAssertEqual(Point(x: 10, y: 10), path.point(at: 1))
        XCTAssertEqual(path, EdgePath(Point(x: 0, y: 0), Point(x: 10, y: 10), Point(x: 20, y: 20)))
        XCTAssertNotEqual(path, EdgePath(Point(x: 0, y: 0), Point(x: 20, y: 20)))
        XCTAssertEqual(3, path.allPoints.count)
    }

    func testEdgeStorage() {
        let storage = EdgeStorage()
        let nodeA = ClassNode()
        let nodeB = ClassNode()
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(nodeA, nodeB)

        XCTAssertTrue(storage.isEmpty)
        XCTAssertFalse(storage.contains(edge))

        storage.store(edge, EdgePath(Point(x: 0, y: 0), Point(x: 10, y: 10)))
        XCTAssertTrue(storage.contains(edge))
        XCTAssertFalse(storage.isEmpty)
        XCTAssertEqual(1, storage.edgesConnectedTo(nodeA).count)
        XCTAssertEqual(1, storage.edgesConnectedTo(nodeB).count)
        XCTAssertFalse(storage.connectionPointIsAvailable(Point(x: 0, y: 0)))
        XCTAssertFalse(storage.connectionPointIsAvailable(Point(x: 10, y: 10)))
        XCTAssertTrue(storage.connectionPointIsAvailable(Point(x: 5, y: 5)))

        let twin = GeneralizationEdge(.inheritance)
        twin.connect(nodeA, nodeB)
        storage.store(twin, EdgePath(Point(x: 0, y: 0), Point(x: 20, y: 20)))
        XCTAssertEqual(1, storage.edgesWithSameNodes(edge).count)
        XCTAssertTrue(storage.edgesWithSameNodes(edge)[0] === twin)

        storage.clear()
        XCTAssertTrue(storage.isEmpty)
    }
}
