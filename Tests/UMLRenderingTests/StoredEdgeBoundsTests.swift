//
//  StoredEdgeBoundsTests.swift
//  UMLExpress
//
//  Class-diagram edges are drawn along a route planned by the layouter. An edge without a
//  route (a copy on the clipboard, an edge added after the layout) must still answer
//  geometry queries — this used to recurse until the stack overflowed.
//

import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLRendering

final class StoredEdgeBoundsTests: XCTestCase {

    private func makeDiagramWithDetachedEdge() -> (Diagram, GeneralizationEdge) {
        let diagram = Diagram(kind: .class)
        let first = ClassNode()
        first.setName("A")
        first.moveTo(Point(x: 40, y: 40))
        let second = ClassNode()
        second.setName("B")
        second.moveTo(Point(x: 40, y: 240))
        diagram.addRootNode(first)
        diagram.addRootNode(second)

        // An edge between the two nodes that is deliberately not part of the diagram, as a
        // clipboard copy is.
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(first, second)
        return (diagram, edge)
    }

    /// Asking for the bounds of an edge without a planned route must return a sensible
    /// rectangle instead of recursing for ever.
    func testBoundsOfAnEdgeWithoutAStoredPath() {
        let (diagram, edge) = makeDiagramWithDetachedEdge()
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let bounds = renderer.boundsOf(edge)
        XCTAssertGreaterThan(bounds.height, 100,
                             "the fallback route spans the two nodes")
        // The nodes are stacked vertically, so the straight fallback route is a vertical
        // line between their facing sides.
        XCTAssertTrue(bounds.contains(Point(x: 90, y: 150)),
                      "the fallback route goes from node to node")
    }

    /// The connection points of such an edge come from its nodes.
    func testConnectionPointsOfAnEdgeWithoutAStoredPath() throws {
        let (diagram, edge) = makeDiagramWithDetachedEdge()
        let concrete = try XCTUnwrap(DiagramRendererFactory.renderer(for: diagram)
            as? AbstractDiagramRenderer)
        let renderer = try XCTUnwrap(concrete.edgeRenderer(for: edge) as? StoredEdgeRenderer)
        let line = renderer.connectionPoints(of: edge)
        XCTAssertLessThan(line.point1.y, line.point2.y,
                          "the edge goes from the upper to the lower node")
        let ends = try XCTUnwrap(concrete.edgeEndPoints(edge))
        XCTAssertEqual(line.point1, ends.0)
        XCTAssertEqual(line.point2, ends.1)
    }

    /// Two nodes on the same spot: the edge between them has no direction, and asking for
    /// its bounds must not trap.
    func testBoundsOfAnEdgeBetweenCoincidentNodes() {
        let diagram = Diagram(kind: .class)
        let first = ClassNode()
        first.setName("A")
        first.moveTo(Point(x: 120, y: 120))
        let second = ClassNode()
        second.setName("B")
        second.moveTo(Point(x: 120, y: 120))
        diagram.addRootNode(first)
        diagram.addRootNode(second)

        let edge = GeneralizationEdge(.inheritance)
        edge.connect(first, second)

        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let bounds = renderer.boundsOf(edge)
        XCTAssertGreaterThanOrEqual(bounds.width, 0)
        XCTAssertGreaterThanOrEqual(bounds.height, 0)
        _ = renderer.diagramBounds()
    }

    /// The bounds of the whole diagram include an edge that has no route yet.
    func testDiagramBoundsWithAnEdgeWithoutAStoredPath() {
        let (diagram, edge) = makeDiagramWithDetachedEdge()
        diagram.addEdge(edge)
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let bounds = renderer.diagramBounds()
        XCTAssertGreaterThan(bounds.height, 200)
    }
}
