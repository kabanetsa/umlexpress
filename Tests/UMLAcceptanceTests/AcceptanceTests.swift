import AppKit
import XCTest
@testable import UMLGeometry
@testable import UMLInteraction
@testable import UMLModel
@testable import UMLOperations
@testable import UMLPersistence
@testable import UMLRendering
@testable import UMLStudio
@testable import UMLValidation

/// End-to-end acceptance tests (M10): the workflows of the user guide, exercised through
/// the same layers the application uses, without a window server.
@MainActor
final class AcceptanceTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("umlexpress-acceptance-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// Creates a session backed by the real factories, as the app does.
    private func makeSession(_ kind: DiagramKind) -> DiagramWindowController.DiagramSession {
        DiagramWindowController.DiagramSession(diagram: Diagram(kind: kind))
    }

    // MARK: - Diagram types

    /// Every diagram type can be created, edited, saved, reopened and exported.
    func testFullCycleForEveryDiagramType() throws {
        // A prototype and a click position inside the canvas per diagram type.
        for kind in DiagramKind.allCases {
            let session = makeSession(kind)
            let controller = session.canvasController

            guard let prototype = kind.prototypes.first(where: { $0 is any Node }) else {
                return XCTFail("no node prototype for \(kind)")
            }
            controller.selectTool(prototype)
            controller.mousePressed(at: Point(x: 100, y: 100))
            controller.mouseReleased(at: Point(x: 100, y: 100))

            // Creating the first node of a diagram must be valid (model + validator agree).
            XCTAssertEqual(1, session.diagram.allNodes.count, "\(kind)")
            XCTAssertTrue(controller.canUndo, "\(kind)")

            let url = directory.appendingPathComponent("diagram-\(kind.rawValue).jet")
            try DiagramCoding.encode(session.diagram).write(to: url)
            let reopened = try DiagramCoding.decode(Data(contentsOf: url))
            XCTAssertEqual(kind, reopened.diagramKind)
            XCTAssertEqual(1, reopened.allNodes.count, "\(kind) round trip")

            // Both export formats work for every type.
            let svg = DiagramExporter.svg(reopened)
            XCTAssertTrue(svg.hasPrefix("<svg viewBox="), "\(kind) SVG")
            let image = DiagramExporter.image(reopened)
            XCTAssertNotNil(image, "\(kind) image")
        }
    }

    /// A class diagram exercise: create nodes, connect them, edit properties, undo, export.
    func testClassDiagramWorkflow() throws {
        let session = makeSession(.class)
        let controller = session.canvasController
        let diagram = session.diagram
        let renderer = controller.renderer

        // Create two classes through the tool palette.
        controller.selectTool(ClassNode())
        controller.mousePressed(at: Point(x: 100, y: 100))
        controller.mouseReleased(at: Point(x: 100, y: 100))
        controller.mousePressed(at: Point(x: 400, y: 100))
        controller.mouseReleased(at: Point(x: 400, y: 100))
        XCTAssertEqual(2, diagram.rootNodes.count)

        let first = try XCTUnwrap(diagram.rootNodes[0] as? ClassNode)
        let second = try XCTUnwrap(diagram.rootNodes[1] as? ClassNode)

        // Name them through the property sheet model, which records undoable operations.
        controller.setSelection(first)
        let sheet = try XCTUnwrap(controller.propertySheetModel())
        controller.applyPropertyChange(sheet.setValue("Client", for: .name))
        XCTAssertEqual("Client", first.name)

        controller.setSelection(second)
        let secondSheet = try XCTUnwrap(controller.propertySheetModel())
        controller.applyPropertyChange(secondSheet.setValue("Server", for: .name))
        controller.applyPropertyChange(secondSheet.setValue("id:int", for: .attributes))
        XCTAssertEqual("id:int", second.attributes)

        // Draw a dependency between the two classes.
        controller.selectTool(DependencyEdge())
        controller.mousePressed(at: renderer.boundsOf(first).center())
        controller.mouseDragged(to: renderer.boundsOf(second).center())
        controller.mouseReleased(at: renderer.boundsOf(second).center())
        XCTAssertEqual(1, diagram.edges.count, "the dependency edge was created")
        XCTAssertTrue(diagram.edges[0] is DependencyEdge)

        // The diagram is semantically valid and renders.
        XCTAssertNil(DiagramValidatorFactory.validator(for: diagram)?.validate())
        let svg = DiagramExporter.svg(diagram)
        XCTAssertTrue(svg.contains(">Client</text>"))
        XCTAssertTrue(svg.contains(">Server</text>"))
        XCTAssertTrue(svg.contains(">id:int</text>"))

        // Undo the edge, then the property changes.
        controller.undo()
        XCTAssertTrue(diagram.edges.isEmpty)
        controller.undo()
        XCTAssertEqual("", second.attributes)
        XCTAssertEqual("Server", second.name)
    }

    /// Opening a real JetUML file renders every element of the diagram.
    func testOpenAndRenderJetUMLFile() throws {
        let fixtures = ["testPersistenceService.class", "testPersistenceService.sequence",
                        "testPersistenceService.state", "testPersistenceService.object",
                        "testPersistenceService.usecase"]
        for name in fixtures {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("UMLPersistenceTests/Fixtures/\(name).jet")
            let diagram = try DiagramCoding.decode(try Data(contentsOf: url))
            let renderer = DiagramRendererFactory.renderer(for: diagram)
            let context = SVGRenderingContext(viewport: renderer.diagramBounds())
            renderer.drawDiagram(context)
            let svg = context.create()

            XCTAssertTrue(svg.hasSuffix("</g></svg>"), "\(name) rendered")
            // Something was drawn: the SVG contains at least one drawing primitive.
            XCTAssertTrue(svg.contains("<rect ") || svg.contains("<ellipse ") || svg.contains("<path "),
                          "\(name) has visible content")
            // Re-encoding is stable.
            let encoded = try DiagramCoding.encode(diagram)
            let decoded = try DiagramCoding.decode(encoded)
            XCTAssertEqual(diagram.allNodes.count, decoded.allNodes.count, "\(name) round trip")
        }
    }

    // MARK: - Cross-cutting behaviour

    func testInvalidOperationsAreRejectedAndReported() {
        let session = makeSession(.class)
        let controller = session.canvasController
        var notifications: [String] = []
        controller.notificationHandler = { notifications.append($0) }

        // A point node without a connecting edge is structurally invalid.
        controller.selectTool(PointNode())
        controller.mousePressed(at: Point(x: 200, y: 200))
        controller.mouseReleased(at: Point(x: 200, y: 200))

        XCTAssertTrue(session.diagram.rootNodes.isEmpty)
        XCTAssertEqual(1, notifications.count)
        XCTAssertFalse(controller.hasUnsavedChanges, "a rejected operation leaves no history")
    }

    func testCopyPasteAndDuplicate() throws {
        let session = makeSession(.class)
        let controller = session.canvasController
        controller.selectTool(ClassNode())
        controller.mousePressed(at: Point(x: 100, y: 100))
        controller.mouseReleased(at: Point(x: 100, y: 100))
        let node = try XCTUnwrap(session.diagram.rootNodes.first)

        controller.setSelection(node)
        controller.copy()
        controller.paste()
        XCTAssertEqual(2, session.diagram.rootNodes.count)
        XCTAssertFalse(session.diagram.rootNodes[1] === node, "the pasted node is a copy")

        let duplicate = session.diagram.duplicate()
        XCTAssertEqual(2, duplicate.rootNodes.count)
        XCTAssertFalse(duplicate.rootNodes[0] === node)
    }

    func testExportsToFiles() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/testPersistenceService.class.jet")
        let diagram = try DiagramCoding.decode(try Data(contentsOf: url))

        let svgURL = directory.appendingPathComponent("out.svg")
        let pngURL = directory.appendingPathComponent("out.png")
        let jetURL = directory.appendingPathComponent("out.class.jet")
        try DiagramExporter.write(diagram, to: svgURL)
        try DiagramExporter.write(diagram, to: pngURL)
        try DiagramExporter.write(diagram, to: jetURL)

        XCTAssertGreaterThan((try Data(contentsOf: svgURL)).count, 100)
        XCTAssertGreaterThan((try Data(contentsOf: pngURL)).count, 500)
        let redecoded = try DiagramCoding.decode(Data(contentsOf: jetURL))
        XCTAssertEqual(diagram.allNodes.count, redecoded.allNodes.count)
    }

    func testRecentFilesQueue() {
        let defaults = UserDefaults(suiteName: "umlexpress.acceptance")!
        defaults.removePersistentDomain(forName: "umlexpress.acceptance")
        let queue = RecentFilesQueue(defaults: defaults)

        let url = directory.appendingPathComponent("a.jet")
        try? Data("{}".utf8).write(to: url)
        queue.add(url)
        XCTAssertEqual(1, queue.recentFiles.count)
        XCTAssertEqual(url.standardizedFileURL.path, queue.recentFiles[0].standardizedFileURL.path)

        // Missing files are ignored, and the queue is capped at five entries.
        queue.add(directory.appendingPathComponent("missing.jet"))
        XCTAssertEqual(1, queue.recentFiles.count)
        for index in 0..<7 {
            let file = directory.appendingPathComponent("f\(index).jet")
            try? Data("{}".utf8).write(to: file)
            queue.add(file)
        }
        XCTAssertEqual(RecentFilesQueue.capacity, queue.recentFiles.count)
        queue.clear()
        XCTAssertTrue(queue.recentFiles.isEmpty)
        defaults.removePersistentDomain(forName: "umlexpress.acceptance")
    }

    func testClipboardImageCopy() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/testPersistenceService.class.jet")
        let diagram = try DiagramCoding.decode(try Data(contentsOf: url))

        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(ClipboardImage.copy(diagram, to: pasteboard))
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
        pasteboard.releaseGlobally()
    }

    /// The parity matrix from the plan (§7) is filled in by `ParityMatrix.md`; this test
    /// keeps the document and the code from drifting apart.
    func testParityMatrixListsEveryDiagramType() throws {
        let matrix = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PARITY-MATRIX.md")
        guard FileManager.default.fileExists(atPath: matrix.path) else {
            throw XCTSkip("PARITY-MATRIX.md is not present")
        }
        let text = try String(contentsOf: matrix, encoding: .utf8)
        for kind in DiagramKind.allCases {
            XCTAssertTrue(text.contains(kind.name), "the matrix must mention \(kind.name)")
        }
    }
}

/// Export and UI integration details added during acceptance (M10).
@MainActor
final class AcceptanceExportTests: XCTestCase {

    private func fixtureDiagram() throws -> Diagram {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/testPersistenceService.class.jet")
        return try DiagramCoding.decode(try Data(contentsOf: url))
    }

    func testPDFExport() throws {
        let data = try XCTUnwrap(DiagramExporter.pdf(try fixtureDiagram()))
        XCTAssertGreaterThan(data.count, 1000)
        XCTAssertEqual("%PDF", String(decoding: data.prefix(4), as: UTF8.self))
    }

    func testPDFFileExport() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("umlexpress-pdf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("diagram.pdf")
        try DiagramExporter.write(try fixtureDiagram(), to: url)
        let data = try Data(contentsOf: url)
        XCTAssertEqual("%PDF", String(decoding: data.prefix(4), as: UTF8.self))
    }

    /// The canvas view paints the background grid and the diagram.
    func testCanvasPaintsGridAndDiagram() throws {
        let document = DiagramDocument(diagram: try fixtureDiagram())
        let view = document.windowController.canvas
        view.setFrameSize(NSSize(width: 400, height: 300))
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)

        var nonWhite = 0
        var dark = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if color.redComponent < 0.95 || color.greenComponent < 0.95 || color.blueComponent < 0.95 {
                    nonWhite += 1
                }
                if color.redComponent < 0.5, color.greenComponent < 0.5, color.blueComponent < 0.5 {
                    dark += 1
                }
            }
        }
        XCTAssertGreaterThan(nonWhite, 100, "the grid and the diagram are visible")
        XCTAssertGreaterThan(dark, 20, "the diagram strokes are visible")
    }

    func testRecentFilesMenuDelegatePopulatesMenu() throws {
        let defaults = UserDefaults(suiteName: "umlexpress.acceptance.menu")!
        defaults.removePersistentDomain(forName: "umlexpress.acceptance.menu")
        defer { defaults.removePersistentDomain(forName: "umlexpress.acceptance.menu") }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("umlexpress-recent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("recent.class.jet")
        try Data("{}".utf8).write(to: file)

        let delegate = RecentFilesMenuDelegate.shared
        delegate.queue = RecentFilesQueue(defaults: defaults)
        delegate.queue.add(file)

        let menu = NSMenu(title: "Open Recent")
        delegate.menuNeedsUpdate(menu)
        XCTAssertEqual("recent.class.jet", menu.items.first?.title)
        XCTAssertTrue(menu.items.contains { $0.title == "Clear Menu" })
    }
}
