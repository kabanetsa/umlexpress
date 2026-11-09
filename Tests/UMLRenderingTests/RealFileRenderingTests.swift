import Foundation
import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLPersistence
@testable import UMLRendering

/// Renders diagrams decoded from the `.jet` files shipped with JetUML: this is the
/// integration point between persistence (M4) and rendering (M3).
final class RealFileRenderingTests: XCTestCase {

    /// Copies of the JetUML fixtures, see `Tests/UMLPersistenceTests/Fixtures`.
    private func fixtureData(_ name: String) throws -> Data {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/\(name).jet")
        return try Data(contentsOf: path)
    }

    func testRenderJetUMLSampleDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixtureData("testPersistenceService.class"))
        let renderer = ClassDiagramRenderer(diagram: diagram)
        let bounds = renderer.diagramBounds()
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)

        let context = SVGRenderingContext(viewport: bounds)
        renderer.draw(context)
        let svg = context.create()

        XCTAssertTrue(svg.hasPrefix("<svg viewBox="))
        XCTAssertTrue(svg.hasSuffix("</g></svg>"))
        // The fixture has 4 classes, 1 interface, 1 note, 1 package and 1 point node.
        XCTAssertTrue(svg.contains(">Node1</text>"))
        XCTAssertTrue(svg.contains(">Node5</text>"))
        XCTAssertTrue(svg.contains("attribute1"))
        XCTAssertTrue(svg.contains("method1"))
        XCTAssertTrue(svg.contains("\u{00AB}interface\u{00BB}"))
        XCTAssertTrue(svg.contains(">Node7</text>"), "the package label")
        XCTAssertTrue(svg.contains("<path d=\"M "), "at least one edge path")
        XCTAssertTrue(svg.contains("stroke-dasharray"), "the dependency edge is dotted")
    }

    func testEveryEdgeGetsAPlannedPath() throws {
        let diagram = try DiagramCoding.decode(try fixtureData("testPersistenceService.class"))
        let renderer = ClassDiagramRenderer(diagram: diagram)
        renderer.layout()
        let storedEdges = diagram.edges.filter { EdgePriority.isStoredEdge($0) }
        XCTAssertFalse(storedEdges.isEmpty)
        for edge in storedEdges {
            XCTAssertNotNil(renderer.storedEdgePath(edge), "no path for \(edge)")
        }
        // Note connectors are not planned: they are drawn as straight dotted lines.
        for edge in diagram.edges where !EdgePriority.isStoredEdge(edge) {
            XCTAssertNil(renderer.storedEdgePath(edge))
        }
        // Every stored path is orthogonal.
        for edge in storedEdges {
            let path = try XCTUnwrap(renderer.storedEdgePath(edge))
            let points = path.allPoints
            for index in 0..<(points.count - 1) {
                XCTAssertTrue(points[index].x == points[index + 1].x || points[index].y == points[index + 1].y,
                              "non-orthogonal segment in \(edge)")
            }
        }
    }

    /// Writes the SVG rendering of the JetUML fixture for manual inspection.
    func testWriteSampleSVGOfJetUMLFile() throws {
        let diagram = try DiagramCoding.decode(try fixtureData("testPersistenceService.class"))
        let renderer = ClassDiagramRenderer(diagram: diagram)
        let context = SVGRenderingContext(viewport: renderer.diagramBounds())
        renderer.draw(context)
        let svg = context.create()

        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Samples")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try svg.write(to: directory.appendingPathComponent("jetumlFixtureDiagram.svg"),
                      atomically: true, encoding: .utf8)
    }

    func testRenderPerformanceDiagram() throws {
        let diagram = try DiagramCoding.decode(try fixtureData("performanceDiagram.class"))
        let renderer = ClassDiagramRenderer(diagram: diagram)
        let context = SVGRenderingContext(viewport: renderer.diagramBounds())
        renderer.draw(context)
        let svg = context.create()
        XCTAssertGreaterThan(svg.count, 1000)
    }
}
