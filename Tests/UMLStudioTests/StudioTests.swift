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

/// Tests for the AppKit layer: the canvas view renders off-screen, and documents
/// save/load through the persistence layer.
@MainActor
final class StudioTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("umlexpress-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    // MARK: - Canvas view

    func testCanvasViewRendersOffscreen() throws {
        let document = DiagramDocument.newDocument()
        let controller = document.session.canvasController
        controller.selectTool(ClassNode())
        controller.mousePressed(at: Point(x: 20, y: 20))
        controller.mouseReleased(at: Point(x: 20, y: 20))

        let view = document.windowController.canvas
        view.setFrameSize(NSSize(width: 300, height: 200))
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)

        XCTAssertGreaterThan(rep.pixelsWide, 0)
        // The class box is drawn: some pixel is dark.
        var darkPixels = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                if let color = rep.colorAt(x: x, y: y),
                   color.redComponent < 0.5, color.greenComponent < 0.5, color.blueComponent < 0.5 {
                    darkPixels += 1
                }
            }
        }
        XCTAssertGreaterThan(darkPixels, 20, "the diagram must be visible in the view")
    }

    func testCanvasViewDrawsLoadedDiagram() throws {
        let url = try fixtureURL("testPersistenceService.class")
        let document = try DiagramDocument.open(url)
        let view = document.windowController.canvas
        view.setFrameSize(NSSize(width: 600, height: 420))
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)

        var darkPixels = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 3) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 3) {
                if let color = rep.colorAt(x: x, y: y),
                   color.redComponent < 0.5, color.greenComponent < 0.5, color.blueComponent < 0.5 {
                    darkPixels += 1
                }
            }
        }
        XCTAssertGreaterThan(darkPixels, 100)
    }

    // MARK: - Documents

    func testNewDocumentIsEmptyAndClean() {
        let document = DiagramDocument.newDocument()
        XCTAssertTrue(document.session.diagram.allNodes.isEmpty)
        XCTAssertFalse(document.hasUnsavedChanges)
        XCTAssertEqual("Untitled", document.title)
    }

    func testSaveAndReopen() throws {
        let document = DiagramDocument.newDocument()
        let controller = document.session.canvasController
        controller.selectTool(ClassNode())
        controller.mousePressed(at: Point(x: 30, y: 30))
        controller.mouseReleased(at: Point(x: 30, y: 30))
        XCTAssertTrue(document.hasUnsavedChanges)

        let url = directory.appendingPathComponent("diagram.class.jet")
        try document.save(to: url)
        XCTAssertFalse(document.hasUnsavedChanges)
        XCTAssertEqual("diagram.class.jet", document.title)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let reopened = try DiagramDocument.open(url)
        XCTAssertEqual(1, reopened.session.diagram.allNodes.count)
        XCTAssertEqual(.class, reopened.session.diagram.diagramKind)
    }

    func testSaveWithoutURLFails() {
        let document = DiagramDocument.newDocument()
        XCTAssertThrowsError(try document.save())
    }

    // MARK: - Export

    func testExportSVG() throws {
        let document = try DiagramDocument.open(try fixtureURL("testPersistenceService.class"))
        let url = directory.appendingPathComponent("diagram.svg")
        try DiagramExporter.write(document.session.diagram, to: url)
        let svg = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(svg.hasPrefix("<svg viewBox="))
        XCTAssertTrue(svg.contains("</g></svg>"))
    }

    func testExportPNG() throws {
        let document = try DiagramDocument.open(try fixtureURL("testPersistenceService.class"))
        let url = directory.appendingPathComponent("diagram.png")
        try DiagramExporter.write(document.session.diagram, to: url)
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 500)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertGreaterThan(rep.pixelsWide, 100)
    }

    func testExporterImageHasContent() throws {
        let document = try DiagramDocument.open(try fixtureURL("testPersistenceService.class"))
        let image = try XCTUnwrap(DiagramExporter.image(document.session.diagram))
        XCTAssertGreaterThan(image.size.width, 100)
        XCTAssertGreaterThan(image.size.height, 100)
    }

    // MARK: - Menu and palette

    func testMainMenuStructure() {
        final class Target: NSObject, EditorActions {
            func newDocument(_ sender: Any?) {}
            func openDocument(_ sender: Any?) {}
            func saveDocument(_ sender: Any?) {}
            func saveDocumentAs(_ sender: Any?) {}
            func exportImage(_ sender: Any?) {}
            func duplicateDiagram(_ sender: Any?) {}
            func copyDiagramToClipboard(_ sender: Any?) {}
            func undo(_ sender: Any?) {}
            func redo(_ sender: Any?) {}
            func cut(_ sender: Any?) {}
            func copy(_ sender: Any?) {}
            func paste(_ sender: Any?) {}
            func delete(_ sender: Any?) {}
            func selectAll(_ sender: Any?) {}
            func zoomIn(_ sender: Any?) {}
            func zoomOut(_ sender: Any?) {}
            func resetZoom(_ sender: Any?) {}
            func toggleDarkMode(_ sender: Any?) {}
            func showFontPanel(_ sender: Any?) {}
            func showWelcome(_ sender: Any?) {}
        }
        let target = Target()
        let menu = MainMenu.build(target: target)
        let titles = menu.items.compactMap { $0.submenu?.title }
        XCTAssertTrue(titles.contains("File"))
        XCTAssertTrue(titles.contains("Edit"))
        XCTAssertTrue(titles.contains("View"))

        let fileMenu = menu.items.first { $0.submenu?.title == "File" }?.submenu
        XCTAssertNotNil(fileMenu?.items.first { $0.title == "New Diagram" }?.submenu)
        let editMenu = menu.items.first { $0.submenu?.title == "Edit" }?.submenu
        XCTAssertNotNil(editMenu?.items.first { $0.title == "Undo" })
    }

    /// "New Diagram" offers every diagram type, so the kind can be chosen instead of
    /// always getting a class diagram.
    func testNewDiagramSubmenuOffersEveryKind() throws {
        final class Target: NSObject, EditorActions {
            func newDocument(_ sender: Any?) {}
            func openDocument(_ sender: Any?) {}
            func saveDocument(_ sender: Any?) {}
            func saveDocumentAs(_ sender: Any?) {}
            func exportImage(_ sender: Any?) {}
            func duplicateDiagram(_ sender: Any?) {}
            func copyDiagramToClipboard(_ sender: Any?) {}
            func undo(_ sender: Any?) {}
            func redo(_ sender: Any?) {}
            func cut(_ sender: Any?) {}
            func copy(_ sender: Any?) {}
            func paste(_ sender: Any?) {}
            func delete(_ sender: Any?) {}
            func selectAll(_ sender: Any?) {}
            func zoomIn(_ sender: Any?) {}
            func zoomOut(_ sender: Any?) {}
            func resetZoom(_ sender: Any?) {}
            func toggleDarkMode(_ sender: Any?) {}
            func showFontPanel(_ sender: Any?) {}
            func showWelcome(_ sender: Any?) {}
        }
        // The menu keeps its target weakly, so it must outlive the build call.
        let target = Target()
        let menu = MainMenu.build(target: target)
        let fileMenu = try XCTUnwrap(menu.items.first { $0.submenu?.title == "File" }?.submenu)
        let newItem = try XCTUnwrap(fileMenu.items.first { $0.title == "New Diagram" })
        let submenu = try XCTUnwrap(newItem.submenu)
        XCTAssertEqual(DiagramKind.allCases.count, submenu.items.count)
        for (index, item) in submenu.items.enumerated() {
            XCTAssertEqual(index, item.tag)
            XCTAssertNotNil(item.target)
            XCTAssertEqual(MainMenu.newDiagramTitles[index], item.title)
            XCTAssertEqual(DiagramKind.allCases[index], MainMenu.diagramKind(forMenuItem: item))
        }
        XCTAssertEqual("n", submenu.items[0].keyEquivalent, "plain New still makes a class diagram")
    }

    /// An item without a usable tag falls back to the class diagram.
    func testNewDiagramKindFallsBackToClass() {
        let item = NSMenuItem(title: "x", action: nil, keyEquivalent: "")
        item.tag = 99
        XCTAssertEqual(.class, MainMenu.diagramKind(forMenuItem: item))
        item.tag = -1
        XCTAssertEqual(.class, MainMenu.diagramKind(forMenuItem: item))
    }

    func testWindowUsesNativeTabs() {
        let document = DiagramDocument.newDocument()
        XCTAssertEqual(.preferred, document.windowController.window?.tabbingMode)
        XCTAssertEqual("UMLExpressDiagram", document.windowController.window?.tabbingIdentifier)
    }

    func testToolPaletteCoversEveryPrototype() {
        let kinds: [DiagramKind] = [.class, .sequence, .state, .object, .useCase]
        for kind in kinds {
            let prototypes = kind.prototypes
            XCTAssertFalse(prototypes.isEmpty)
            for prototype in prototypes {
                XCTAssertNotEqual("?", DiagramWindowController.shortLabel(for: prototype),
                                  "missing palette label for \(type(of: prototype))")
            }
        }
    }

    // MARK: - Helpers

    private func fixtureURL(_ name: String) throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UMLPersistenceTests/Fixtures/\(name).jet")
    }
}

/// Regression tests for the event wiring of the canvas view: a click on the canvas must
/// reach the controller, otherwise tools appear to do nothing.
@MainActor
final class CanvasInteractionWiringTests: XCTestCase {

    private func makeView() -> (DiagramDocument, DiagramCanvasView) {
        let document = DiagramDocument.newDocument()
        let view = document.windowController.canvas
        view.setFrameSize(NSSize(width: 800, height: 600))
        return (document, view)
    }

    /// Builds a mouse event whose location is given in *canvas* coordinates, converting it
    /// to window coordinates the way AppKit would deliver it.
    private func mouseEvent(_ type: NSEvent.EventType, at canvasPoint: NSPoint,
                            in view: DiagramCanvasView, clickCount: Int = 1) -> NSEvent {
        let windowPoint = view.convert(canvasPoint, to: nil)
        return NSEvent.mouseEvent(with: type, location: windowPoint, modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: view.window?.windowNumber ?? 0, context: nil,
                                  eventNumber: 0, clickCount: clickCount, pressure: 1)!
    }

    /// A single click with a creation tool must create a node through the view.
    func testSingleClickCreatesNodeThroughView() {
        let (document, view) = makeView()
        view.controller.selectTool(ClassNode())

        view.mouseDown(with: mouseEvent(.leftMouseDown, at: NSPoint(x: 40, y: 50), in: view))
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: NSPoint(x: 40, y: 50), in: view))

        XCTAssertEqual(1, document.session.diagram.rootNodes.count,
                       "the click must reach the canvas controller")
        XCTAssertEqual(Point(x: 40, y: 50), document.session.diagram.rootNodes[0].position)
    }

    /// A single click with the selection tool selects the node under the cursor.
    func testSingleClickSelectsThroughView() {
        let (document, view) = makeView()
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 0, y: 0))
        document.session.diagram.addRootNode(node)

        view.mouseDown(with: mouseEvent(.leftMouseDown, at: NSPoint(x: 50, y: 30), in: view))
        XCTAssertEqual(1, view.controller.selection.count)
        XCTAssertTrue(view.controller.selection[0] === node)
    }

    /// A drag with an edge tool creates an edge between two nodes.
    func testDragCreatesEdgeThroughView() {
        let (document, view) = makeView()
        let first = ClassNode()
        first.setName("A")
        first.moveTo(Point(x: 0, y: 0))
        let second = ClassNode()
        second.setName("B")
        second.moveTo(Point(x: 0, y: 200))
        document.session.diagram.addRootNode(first)
        document.session.diagram.addRootNode(second)

        view.controller.selectTool(GeneralizationEdge(.inheritance))
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: NSPoint(x: 50, y: 30), in: view))
        view.mouseDragged(with: mouseEvent(.leftMouseDragged, at: NSPoint(x: 50, y: 230), in: view))
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: NSPoint(x: 50, y: 230), in: view))

        XCTAssertEqual(1, document.session.diagram.edges.count)
        XCTAssertTrue(document.session.diagram.edges[0] is GeneralizationEdge)
    }

    /// A double click opens the property sheet instead of using the tool.
    func testDoubleClickRequestsPropertySheet() {
        let (document, view) = makeView()
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 0, y: 0))
        document.session.diagram.addRootNode(node)
        view.controller.setSelection(node)

        var opened = false
        view.onDoubleClick = { opened = true }
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: NSPoint(x: 50, y: 30), in: view,
                                        clickCount: 2))

        XCTAssertTrue(opened, "a double click must open the property sheet")
        XCTAssertEqual(1, document.session.diagram.rootNodes.count, "no node is created")
    }
}

/// Coordinate conversion between the window and the (flipped) canvas.
@MainActor
final class CanvasCoordinateTests: XCTestCase {

    func testConversionRoundTripWithWindow() throws {
        let document = DiagramDocument.newDocument()
        let view = document.windowController.canvas
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        window.contentView = view

        let canvasPoint = NSPoint(x: 120, y: 80)
        let windowPoint = view.convert(canvasPoint, to: nil)
        // The view is flipped, so the window coordinate differs in y, but converting back
        // must return the canvas point.
        let back = view.canvasLocation(of: windowPoint)
        XCTAssertEqual(canvasPoint.x, back.x, accuracy: 0.5)
        XCTAssertEqual(canvasPoint.y, back.y, accuracy: 0.5)
    }

    func testClickWithWindowCreatesNodeAtCanvasPoint() {
        let document = DiagramDocument.newDocument()
        let view = document.windowController.canvas
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        window.contentView = view
        view.controller.selectTool(ClassNode())

        let canvasPoint = NSPoint(x: 200, y: 120)
        let windowPoint = view.convert(canvasPoint, to: nil)
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: windowPoint, modifierFlags: [],
                                       timestamp: 0, windowNumber: window.windowNumber,
                                       context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        view.mouseDown(with: event)

        XCTAssertEqual(1, document.session.diagram.rootNodes.count)
        XCTAssertEqual(Point(x: 200, y: 120), document.session.diagram.rootNodes[0].position)
    }
}

/// The property sheet window: edits are applied live and committed with one undo step.
@MainActor
final class PropertySheetWindowTests: XCTestCase {

    private func makeSetup() -> (DiagramDocument, ClassNode, PropertySheetWindow) {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 10, y: 10))
        document.session.diagram.addRootNode(node)
        document.session.canvasController.setSelection(node)
        let sheet = PropertySheetWindow(controller: document.session.canvasController,
                                       onChange: {})
        return (document, node, sheet!)
    }

    func testTextViewEditsAreAppliedAndCommitted() throws {
        let (document, node, sheet) = makeSetup()
        // Class nodes use a multi-line editor for their text properties.
        let textView = try XCTUnwrap(sheet.textView(for: .name))
        textView.string = "Renamed"
        sheet.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        XCTAssertEqual("Renamed", node.name, "the edit is applied while typing")

        XCTAssertFalse(document.session.canvasController.canUndo,
                       "no undo step while the sheet is open")
        sheet.commitPendingChanges()
        XCTAssertTrue(document.session.canvasController.canUndo)
        document.session.canvasController.undo()
        XCTAssertEqual("A", node.name)
    }

    func testPopUpEditsAreAppliedAndCommitted() throws {
        let document = DiagramDocument.newDocument()
        let edge = AggregationEdge(.aggregation)
        let first = ClassNode()
        let second = ClassNode()
        first.moveTo(Point(x: 0, y: 0))
        second.moveTo(Point(x: 0, y: 200))
        edge.connect(first, second)
        document.session.diagram.addRootNode(first)
        document.session.diagram.addRootNode(second)
        document.session.diagram.addEdge(edge)
        document.session.canvasController.setSelection(edge)

        let sheet = try XCTUnwrap(PropertySheetWindow(controller: document.session.canvasController,
                                                     onChange: {}))
        let popUp = try XCTUnwrap(sheet.popUp(for: .aggregationType))
        popUp.selectItem(withTitle: "Composition")
        sheet.commitPendingChanges()

        XCTAssertEqual(.composition, edge.type)
        document.session.canvasController.undo()
        XCTAssertEqual(.aggregation, edge.type)
    }

    func testNoSheetWithoutASingleSelection() {
        let document = DiagramDocument.newDocument()
        XCTAssertNil(PropertySheetWindow(controller: document.session.canvasController,
                                        onChange: {}))
        let first = ClassNode()
        let second = ClassNode()
        document.session.diagram.addRootNode(first)
        document.session.diagram.addRootNode(second)
        document.session.canvasController.setSelection([first, second])
        XCTAssertNil(PropertySheetWindow(controller: document.session.canvasController,
                                        onChange: {}),
                     "two elements selected means nothing to edit")
    }
}

/// Closing the sheet without touching a control must not create an undo step, and a value
/// typed but never "committed" by the control must still be saved (the reported bug).
@MainActor
final class PropertySheetCommitTests: XCTestCase {

    func testDoneWithUntouchedFieldsCreatesNoUndoStep() throws {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        document.session.diagram.addRootNode(node)
        document.session.canvasController.setSelection(node)
        let sheet = try XCTUnwrap(PropertySheetWindow(controller: document.session.canvasController,
                                                     onChange: {}))
        sheet.commitPendingChanges()
        XCTAssertFalse(document.session.canvasController.canUndo)
    }

    func testTypedValueWithoutEditingEndIsStillSaved() throws {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        document.session.diagram.addRootNode(node)
        document.session.canvasController.setSelection(node)
        let sheet = try XCTUnwrap(PropertySheetWindow(controller: document.session.canvasController,
                                                     onChange: {}))
        // Simulate typing directly into the text view without any delegate callback.
        let textView = try XCTUnwrap(sheet.textView(for: .name))
        textView.string = "Typed but not committed"
        sheet.commitPendingChanges()

        XCTAssertEqual("Typed but not committed", node.name,
                       "Done must read the control values, not rely on editing events")
        document.session.canvasController.undo()
        XCTAssertEqual("A", node.name)
    }

    func testEscapeKeepsTheChanges() throws {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        document.session.diagram.addRootNode(node)
        document.session.canvasController.setSelection(node)
        let sheet = try XCTUnwrap(PropertySheetWindow(controller: document.session.canvasController,
                                                     onChange: {}))
        let textView = try XCTUnwrap(sheet.textView(for: .name))
        textView.string = "Kept"
        sheet.cancelOperation(nil)
        XCTAssertEqual("Kept", node.name, "as in the original dialog, closing keeps the edits")
        XCTAssertTrue(document.session.canvasController.canUndo)
    }
}

/// The sheet controller must outlive the call that presents it, otherwise the controls
/// lose their target/delegates and Done does nothing.
@MainActor
final class PropertySheetRetentionTests: XCTestCase {

    func testSheetControllerIsRetainedWhileOpen() throws {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        document.session.diagram.addRootNode(node)
        document.session.canvasController.setSelection(node)

        let windowController = document.windowController
        weak var weakSheet: PropertySheetWindow?
        do {
            let sheet = try XCTUnwrap(windowController.presentPropertySheet())
            weakSheet = sheet
            XCTAssertNotNil(weakSheet, "the sheet controller is alive while presented")
            XCTAssertTrue(windowController.propertySheetController === sheet)
        }
        // Still alive after the presenting scope ends: the window controller owns it.
        XCTAssertNotNil(weakSheet, "the sheet controller must outlive the call site")
    }

    /// With the sheet retained, edits and the Done commit path work through the window
    /// controller exactly as in the running application.
    func testEditingThroughRetainedSheetSavesTheValue() throws {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        document.session.diagram.addRootNode(node)
        document.session.canvasController.setSelection(node)

        let sheet = try XCTUnwrap(document.windowController.presentPropertySheet())
        let textView = try XCTUnwrap(sheet.textView(for: .name))
        textView.string = "Renamed in the sheet"
        sheet.commitPendingChanges()

        XCTAssertEqual("Renamed in the sheet", node.name)
        XCTAssertTrue(document.session.canvasController.canUndo)

        // Rendering reflects the new name.
        let svg = DiagramExporter.svg(document.session.diagram)
        XCTAssertTrue(svg.contains(">Renamed in the sheet</text>"))

        document.session.canvasController.undo()
        XCTAssertEqual("A", node.name)
    }
}

/// The drawing area must follow the window: a big window offers more room to draw in.
///
/// The original canvas has a fixed size and the controller keeps elements inside it, so a
/// canvas that stays at its initial 1000 points leaves everything right of the middle of a
/// maximised window unreachable.
@MainActor
final class CanvasExtentTests: XCTestCase {

    private func makeCanvas(width: CGFloat) -> (DiagramDocument, DiagramCanvasView) {
        let document = DiagramDocument.newDocument()
        guard let window = document.windowController.window,
              let content = window.contentView else {
            fatalError("the document must own a window")
        }
        window.setFrame(NSRect(x: 0, y: 0, width: width, height: 900), display: false)
        content.layoutSubtreeIfNeeded()
        return (document, document.windowController.canvas)
    }

    private func mouseEvent(_ type: NSEvent.EventType, at canvasPoint: NSPoint,
                            in view: DiagramCanvasView) -> NSEvent {
        let windowPoint = view.convert(canvasPoint, to: nil)
        return NSEvent.mouseEvent(with: type, location: windowPoint, modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: view.window?.windowNumber ?? 0, context: nil,
                                  eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    /// The canvas is at least as wide as the area the window shows.
    func testCanvasGrowsWithTheWindow() {
        let (document, canvas) = makeCanvas(width: 1800)
        let visible = canvas.enclosingScrollView?.contentView.bounds.width ?? 0
        XCTAssertGreaterThan(visible, 1200, "the window must really be wide for this test")
        XCTAssertGreaterThanOrEqual(canvas.frame.width, visible,
                                    "the canvas must cover the visible area")
        XCTAssertGreaterThanOrEqual(
            document.session.canvasController.canvasDimension.width, Int(visible),
            "the controller must know the real canvas width")
    }

    /// A shape can be dragged into the right part of a large window.
    func testShapesCanBeDraggedIntoTheRightPartOfALargeWindow() {
        let (document, canvas) = makeCanvas(width: 1800)
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 0, y: 0))
        document.session.diagram.addRootNode(node)

        canvas.mouseDown(with: mouseEvent(.leftMouseDown, at: NSPoint(x: 50, y: 30), in: canvas))
        canvas.mouseDragged(with: mouseEvent(.leftMouseDragged,
                                             at: NSPoint(x: 1500, y: 230), in: canvas))
        canvas.mouseUp(with: mouseEvent(.leftMouseUp, at: NSPoint(x: 1500, y: 230), in: canvas))

        XCTAssertGreaterThan(node.position.x, 1000,
                             "the shape must be able to pass the old 1000-point limit")
        XCTAssertEqual(1450, node.position.x, "the shape follows the cursor")
    }

    /// A shrunk window shrinks the canvas back to what is visible.
    func testCanvasShrinksBackWithTheWindow() {
        let (_, canvas) = makeCanvas(width: 1800)
        let grown = canvas.frame.width
        guard let window = canvas.window, let content = window.contentView else {
            return XCTFail("no window")
        }
        window.setFrame(NSRect(x: 0, y: 0, width: 900, height: 600), display: false)
        content.layoutSubtreeIfNeeded()
        XCTAssertLessThan(canvas.frame.width, grown)
        XCTAssertGreaterThanOrEqual(canvas.frame.width,
                                    canvas.enclosingScrollView?.contentView.bounds.width ?? 0)
    }
}

/// The welcome window must lay its content out with a margin on every side.
///
/// `NSStackView.fittingSize` counts the edge insets only on one side, which glued the
/// buttons of the welcome window to the right edge of the window.
@MainActor
final class WelcomeWindowLayoutTests: XCTestCase {

    private func makeWindow(recent: [URL]) -> (WelcomeWindowController, NSWindow, NSStackView) {
        let controller = WelcomeWindowController()
        controller.recentFiles = recent
        guard let window = controller.window,
              let stack = window.contentView as? NSStackView else {
            fatalError("the welcome window must use a stack view")
        }
        stack.layoutSubtreeIfNeeded()
        return (controller, window, stack)
    }

    private func temporaryRecentFiles(_ names: [String]) throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("welcome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try names.map { name in
            let url = directory.appendingPathComponent(name)
            try Data("{}".utf8).write(to: url)
            return url
        }
    }

    func testContentHasAMarginOnTheRight() throws {
        let recent = try temporaryRecentFiles(["a.jet", "b.jet"])
        let (_, _, stack) = makeWindow(recent: recent)
        let margin = stack.edgeInsets
        for view in stack.arrangedSubviews {
            // Labels are drawn a couple of points to the left of their frame.
            XCTAssertGreaterThanOrEqual(view.frame.minX, margin.left - 3,
                                        "\(view) must start after the left margin")
            XCTAssertLessThanOrEqual(view.frame.maxX,
                                     stack.bounds.width - margin.right + 1,
                                     "\(view) must end before the right margin")
        }
    }

    /// The window is exactly as large as its content plus the margins.
    func testWindowSizeIncludesTheInsets() throws {
        let recent = try temporaryRecentFiles(["a.jet"])
        let (_, window, stack) = makeWindow(recent: recent)
        let expected = WelcomeWindowController.contentSize(of: stack)
        XCTAssertEqual(expected.width, window.contentLayoutRect.width, accuracy: 1)
        XCTAssertEqual(expected.height, window.contentLayoutRect.height, accuracy: 1)
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.width,
                                    stack.edgeInsets.left + stack.edgeInsets.right)
    }

    /// A long file name does not stretch the window: the row truncates instead.
    func testLongRecentFileNameDoesNotStretchTheWindow() throws {
        let short = try temporaryRecentFiles(["a.jet"])
        let long = try temporaryRecentFiles([String(repeating: "a-very-long-name", count: 6) + ".jet"])
        let shortWidth = makeWindow(recent: short).1.contentLayoutRect.width
        let longWidth = makeWindow(recent: long).1.contentLayoutRect.width
        XCTAssertEqual(shortWidth, longWidth, accuracy: 1)
        XCTAssertLessThan(longWidth, 400)
    }

    /// A file that no longer exists is not listed, and neither is a duplicate.
    func testMissingAndDuplicateFilesAreNotListed() throws {
        let recent = try temporaryRecentFiles(["first.jet", "second.jet"])
        let missing = recent[0].deletingLastPathComponent().appendingPathComponent("gone.jet")
        let (controller, _, stack) = makeWindow(recent: recent + [missing, recent[0]])
        _ = controller
        let recentButtons = stack.arrangedSubviews.compactMap { $0 as? NSButton }
            .filter { $0.bezelStyle == .inline }
        XCTAssertEqual(2, recentButtons.count)
        XCTAssertEqual([recent[0].path, recent[1].path], recentButtons.compactMap(\.toolTip))
    }

    /// One row per recent file, with the full path as a tooltip.
    func testOneRowPerRecentFile() throws {
        let recent = try temporaryRecentFiles(["first.jet", "second.jet"])
        let (_, _, stack) = makeWindow(recent: recent)
        let recentButtons = stack.arrangedSubviews.compactMap { $0 as? NSButton }
            .filter { $0.bezelStyle == .inline }
        XCTAssertEqual(2, recentButtons.count)
        XCTAssertEqual(recent[0].path, recentButtons[0].toolTip)
        XCTAssertEqual(recent[1].path, recentButtons[1].toolTip)
    }
}

/// The queue must not list the same file twice, however its path is spelled.
final class RecentFilesQueueDeduplicationTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "umlexpress.tests.recent.\(UUID().uuidString)")
    }

    private func makeFile(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("recent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data("{}".utf8).write(to: url)
        return url
    }

    func testSameSpellingKeepsOneEntry() throws {
        let file = try makeFile("diagram.jet")
        let queue = RecentFilesQueue(defaults: defaults)
        queue.add(file)
        queue.add(file)
        queue.add(file.standardizedFileURL)
        XCTAssertEqual(1, queue.recentFiles.count)
    }

    /// APFS is case-insensitive by default: two spellings are the same file.
    func testDifferentCaseKeepsOneEntry() throws {
        let file = try makeFile("diagram.jet")
        let queue = RecentFilesQueue(defaults: defaults)
        queue.add(file)
        queue.add(file.deletingLastPathComponent().appendingPathComponent("DIAGRAM.JET"))
        XCTAssertEqual(1, queue.recentFiles.count)
    }

    func testParentPathSpellingsKeepOneEntry() throws {
        let file = try makeFile("diagram.jet")
        let roundabout = file.deletingLastPathComponent()
            .appendingPathComponent("..")
            .appendingPathComponent(file.deletingLastPathComponent().lastPathComponent)
            .appendingPathComponent("diagram.jet")
        let queue = RecentFilesQueue(defaults: defaults)
        queue.add(file)
        queue.add(roundabout)
        XCTAssertEqual(1, queue.recentFiles.count)
    }

    /// Stored duplicates and stale entries are dropped when the queue is loaded.
    func testStoredDuplicatesAndStaleFilesAreDropped() throws {
        let file = try makeFile("diagram.jet")
        let missing = file.deletingLastPathComponent().appendingPathComponent("gone.jet")
        defaults.set([file.path, file.path, missing.path], forKey: "recentFiles")
        let queue = RecentFilesQueue(defaults: defaults)
        XCTAssertEqual([file.standardizedFileURL], queue.recentFiles)
    }
}

/// The canvas must show what is selected: an outline and corner handles.
@MainActor
final class SelectionHandleTests: XCTestCase {

    private func render(_ view: DiagramCanvasView) throws -> NSBitmapImageRep {
        view.setFrameSize(NSSize(width: 400, height: 300))
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    private func differs(_ first: NSColor?, _ second: NSColor?) -> Bool {
        guard let first = first?.usingColorSpace(.sRGB),
              let second = second?.usingColorSpace(.sRGB) else {
            return false
        }
        return abs(first.redComponent - second.redComponent) > 0.05
            || abs(first.greenComponent - second.greenComponent) > 0.05
            || abs(first.blueComponent - second.blueComponent) > 0.05
    }

    /// A selected node is outlined and gets a handle at each corner.
    func testSelectionDrawsHandlesAtTheCorners() throws {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 50, y: 60))
        document.session.diagram.addRootNode(node)
        let view = document.windowController.canvas

        let before = try render(view)
        view.controller.setSelection([node])
        let after = try render(view)

        var changed: [(Int, Int)] = []
        for y in stride(from: 0, to: min(before.pixelsHigh, after.pixelsHigh), by: 2) {
            for x in stride(from: 0, to: min(before.pixelsWide, after.pixelsWide), by: 2)
            where differs(before.colorAt(x: x, y: y), after.colorAt(x: x, y: y)) {
                changed.append((x, y))
            }
        }
        XCTAssertGreaterThan(changed.count, 50, "the selection must be visible")

        // The bitmap is rendered at the backing scale of the display, the canvas keeps
        // points; the bitmap rows follow the flipped view (y grows downwards).
        let scale = CGFloat(after.pixelsWide) / view.bounds.width
        let tolerance = Int((DiagramCanvasView.handleSize / 2 + 3) * scale)
        let bounds = view.controller.renderer.boundsOf(node)
        let corners = [Point(x: bounds.x, y: bounds.y), Point(x: bounds.maxX, y: bounds.y),
                       Point(x: bounds.x, y: bounds.maxY), Point(x: bounds.maxX, y: bounds.maxY)]
        for corner in corners {
            let x = Int(CGFloat(corner.x) * scale)
            let y = Int(CGFloat(corner.y) * scale)
            let nearby = changed.contains { abs($0.0 - x) <= tolerance && abs($0.1 - y) <= tolerance }
            XCTAssertTrue(nearby, "there must be a handle near \(corner)")
        }
    }

    /// Nothing is drawn for an empty selection.
    func testNoSelectionDrawsNoHandles() throws {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 50, y: 60))
        document.session.diagram.addRootNode(node)
        let view = document.windowController.canvas

        view.controller.setSelection([])
        let first = try render(view)
        let second = try render(view)
        for y in stride(from: 0, to: first.pixelsHigh, by: 3) {
            for x in stride(from: 0, to: first.pixelsWide, by: 3) {
                XCTAssertFalse(differs(first.colorAt(x: x, y: y), second.colorAt(x: x, y: y)),
                               "an empty selection must not change the picture")
            }
        }
    }
}

/// A selected connecting line is marked only at its ends: no dashed box around it.
@MainActor
final class EdgeSelectionHandleTests: XCTestCase {

    private func makeDiagram() -> (DiagramDocument, DiagramCanvasView, GeneralizationEdge) {
        let document = DiagramDocument.newDocument()
        let controller = document.session.canvasController
        let top = ClassNode()
        top.setName("A")
        top.moveTo(Point(x: 80, y: 60))
        let bottom = ClassNode()
        bottom.setName("B")
        bottom.moveTo(Point(x: 80, y: 260))
        document.session.diagram.addRootNode(top)
        document.session.diagram.addRootNode(bottom)

        controller.selectTool(GeneralizationEdge(.inheritance))
        controller.mousePressed(at: Point(x: 130, y: 80))
        controller.mouseDragged(to: Point(x: 130, y: 280))
        controller.mouseReleased(at: Point(x: 130, y: 280))
        let view = document.windowController.canvas
        view.setFrameSize(NSSize(width: 400, height: 400))
        let edge = document.session.diagram.edges.first as! GeneralizationEdge
        return (document, view, edge)
    }

    private func changedPixels(_ first: NSBitmapImageRep,
                               _ second: NSBitmapImageRep) -> [(Int, Int)] {
        var changed: [(Int, Int)] = []
        for y in stride(from: 0, to: min(first.pixelsHigh, second.pixelsHigh), by: 3) {
            for x in stride(from: 0, to: min(first.pixelsWide, second.pixelsWide), by: 3) {
                guard let a = first.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      let b = second.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                    continue
                }
                if abs(a.redComponent - b.redComponent) > 0.05
                    || abs(a.greenComponent - b.greenComponent) > 0.05
                    || abs(a.blueComponent - b.blueComponent) > 0.05 {
                    changed.append((x, y))
                }
            }
        }
        return changed
    }

    private func bitmap(_ view: DiagramCanvasView) throws -> NSBitmapImageRep {
        view.display()
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    func testEdgeSelectionMarksOnlyTheEnds() throws {
        let (_, view, edge) = makeDiagram()
        // Drawing the edge leaves it selected: capture the unselected picture first.
        view.controller.clearSelection()
        let before = try bitmap(view)
        view.controller.setSelection([edge])
        let after = try bitmap(view)
        let changed = changedPixels(before, after)
        XCTAssertEqual(1, view.controller.selection.count)
        XCTAssertGreaterThan(changed.count, 20, "the selection must be visible")

        let scale = CGFloat(after.pixelsWide) / view.bounds.width
        let tolerance = Int((DiagramCanvasView.handleSize / 2 + 3) * scale)
        let ends = try XCTUnwrap(view.controller.renderer.edgeEndPoints(edge))
        for end in [ends.0, ends.1] {
            let x = Int(CGFloat(end.x) * scale)
            let y = Int(CGFloat(end.y) * scale)
            XCTAssertTrue(changed.contains { abs($0.0 - x) <= tolerance && abs($0.1 - y) <= tolerance },
                          "there must be a handle at \(end)")
        }

        // Far from the line there is nothing: no box around the edge.
        let bounds = view.controller.renderer.boundsOf(edge)
        let corner = (x: Int(CGFloat(bounds.maxX) * scale), y: Int(CGFloat(bounds.y) * scale))
        let nearEnd = [ends.0, ends.1].contains {
            abs(Int(CGFloat($0.x) * scale) - corner.x) <= tolerance * 3
                && abs(Int(CGFloat($0.y) * scale) - corner.y) <= tolerance * 3
        }
        if !nearEnd {
            let touched = changed.contains {
                abs($0.0 - corner.x) <= tolerance && abs($0.1 - corner.y) <= tolerance
            }
            XCTAssertFalse(touched, "an edge must not get a box at \(corner)")
        }
    }
}

/// Zoom, as in the original View menu: in, out and back to actual size.
@MainActor
final class CanvasZoomTests: XCTestCase {

    private func makeCanvas() -> (DiagramDocument, DiagramCanvasView) {
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 40, y: 40))
        document.session.diagram.addRootNode(node)
        let view = document.windowController.canvas
        view.setFrameSize(NSSize(width: 400, height: 300))
        return (document, view)
    }

    func testZoomInAndOutChangeTheZoomFactor() {
        let (_, view) = makeCanvas()
        XCTAssertEqual(1.0, view.zoom, accuracy: 0.001)
        view.zoomIn()
        XCTAssertEqual(1.25, view.zoom, accuracy: 0.001)
        view.zoomIn()
        XCTAssertEqual(1.5625, view.zoom, accuracy: 0.001)
        view.zoomIn()
        XCTAssertEqual(1.5625, view.zoom, accuracy: 0.001, "the zoom stops at the maximum")
        view.zoomOut()
        view.zoomOut()
        XCTAssertEqual(1.0, view.zoom, accuracy: 0.001)
        view.zoomOut()
        view.zoomOut()
        view.zoomOut()
        XCTAssertEqual(0.64, view.zoom, accuracy: 0.001, "the zoom stops at the minimum")
        view.resetZoom()
        XCTAssertEqual(1.0, view.zoom, accuracy: 0.001)
    }

    /// Zooming magnifies the picture: the same diagram covers more pixels.
    func testZoomMakesTheDiagramBigger() throws {
        let (_, view) = makeCanvas()
        func darkPixels() throws -> Int {
            view.display()
            let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)
            var count = 0
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                    if let color = rep.colorAt(x: x, y: y), color.redComponent < 0.5,
                       color.greenComponent < 0.5, color.blueComponent < 0.5 {
                        count += 1
                    }
                }
            }
            return count
        }
        let normal = try darkPixels()
        view.zoomIn()
        view.zoomIn()
        let zoomed = try darkPixels()
        XCTAssertGreaterThan(normal, 20)
        XCTAssertGreaterThan(zoomed, normal, "zoom must magnify the diagram")
    }

    /// Clicks are converted back to canvas coordinates, so a tool still lands where the
    /// cursor is.
    func testClicksMapToTheRightCanvasPositionWhenZoomed() {
        let (document, view) = makeCanvas()
        view.zoomIn()
        view.zoomIn()
        view.controller.selectTool(ClassNode())
        // A point away from the node already in the diagram, chosen so that the canvas
        // position is a multiple of the grid (positions are snapped to it).
        let target = NSPoint(x: 312.5, y: 200)
        let windowPoint = view.convert(target, to: nil)
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: windowPoint,
                                       modifierFlags: [], timestamp: 0,
                                       windowNumber: view.window?.windowNumber ?? 0,
                                       context: nil, eventNumber: 0, clickCount: 1,
                                       pressure: 1)!
        view.mouseDown(with: event)
        view.mouseUp(with: event)

        XCTAssertEqual(2, document.session.diagram.rootNodes.count, "the click must create a node")
        let created = document.session.diagram.rootNodes.last
        let expected = Int((target.x / view.zoom).rounded())
        XCTAssertEqual(expected, created?.position.x,
                       "the click must be converted from view points to canvas points")
    }
}

/// The property sheet shows readable control labels and visible fields.
@MainActor
final class PropertySheetAppearanceTests: XCTestCase {

    private func makeSheet(element: any DiagramElement) -> (DiagramDocument, PropertySheetWindow) {
        let document = DiagramDocument.newDocument()
        document.session.diagram.addRootNode(element as! any Node)
        document.session.canvasController.setSelection(element)
        let sheet = PropertySheetWindow(controller: document.session.canvasController,
                                        onChange: {})
        return (document, sheet!)
    }

    /// Labels are capitalised words, as in the original's resource bundle.
    func testLabelsAreCapitalised() {
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 10, y: 10))
        let (_, sheet) = makeSheet(element: node)
        XCTAssertEqual(["Name", "Attributes", "Methods"], sheet.model.rows.map(\.label))

        // Every label of every element type is a capitalised word.
        for kind in DiagramKind.allCases {
            for prototype in kind.prototypes {
                guard let node = prototype as? (any Node) else { continue }
                let document = DiagramDocument.newDocument(kind: kind)
                document.session.diagram.addRootNode(node)
                document.session.canvasController.setSelection(node)
                guard let sheet = PropertySheetWindow(controller: document.session.canvasController,
                                                     onChange: {}) else {
                    continue
                }
                for label in sheet.model.rows.map(\.label) {
                    let first = label.first.map(String.init) ?? ""
                    XCTAssertEqual(first, first.uppercased(),
                                   "\(type(of: node)): the label \"\(label)\" starts in lowercase")
                    XCTAssertFalse(label.hasPrefix(" "), "the label must not be indented")
                }
            }
        }
    }

    /// The multi-line editors are framed exactly like the single-line fields: a rounded
    /// one-point border that turns blue while the cursor is in the control.
    func testMultilineEditorsAreFramedLikeFields() throws {
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 10, y: 10))
        let (_, sheet) = makeSheet(element: node)

        for name in [PropertyName.name, .attributes, .methods] {
            let view = try XCTUnwrap(sheet.textView(for: name))
            let frame = try XCTUnwrap(sheet.editorFrame(for: name), "\(name) needs a frame")
            XCTAssertGreaterThan(EditorFrame.cornerRadius, 0, "\(name) must have rounded corners")
            XCTAssertEqual(EditorFrame.borderWidth, 1)
            XCTAssertTrue(frame.editor === view.enclosingScrollView,
                          "the frame must hold the whole editor")
            XCTAssertTrue(frame.focusRing.superview === frame, "the ring must be in the hierarchy")
        }

        // The ring fades in when the editor takes the focus and out when it loses it; it
        // is drawn in the accent colour, like the ring of a text field.
        let view = try XCTUnwrap(sheet.textView(for: .attributes))
        let editor = try XCTUnwrap(view as? EditorTextView,
                                   "the editor must report the focus")
        let frame = try XCTUnwrap(sheet.editorFrame(for: .attributes))
        XCTAssertFalse(frame.isActive)
        XCTAssertEqual(0, frame.focusRingOpacity)
        XCTAssertEqual(0, frame.focusRingTargetOpacity)

        editor.focusHandler?(true)
        XCTAssertTrue(frame.isActive, "the frame must show the focus ring while the editor is used")
        XCTAssertEqual(1, frame.focusRingOpacity, "the ring must be drawn while the editor is used")
        XCTAssertEqual(1, frame.focusRingTargetOpacity)
        XCTAssertEqual(EditorFrame.fadeDuration, 0.15, accuracy: 0.001)

        editor.focusHandler?(false)
        XCTAssertFalse(frame.isActive)
        XCTAssertEqual(0, frame.focusRingOpacity)
        XCTAssertEqual(0, frame.focusRingTargetOpacity)
    }

    /// The ring is really painted: the sheet is rendered before and after the editor gets
    /// the focus, and the picture gains accent-coloured pixels around the frame.
    func testFocusRingIsPainted() throws {
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 10, y: 10))
        let (_, sheet) = makeSheet(element: node)
        let content = try XCTUnwrap(sheet.window?.contentView)
        let editor = try XCTUnwrap(sheet.textView(for: .attributes) as? EditorTextView)
        let frame = try XCTUnwrap(sheet.editorFrame(for: .attributes))

        func bluePixels() throws -> Int {
            content.layoutSubtreeIfNeeded()
            let rep = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
            content.cacheDisplay(in: content.bounds, to: rep)
            var count = 0
            for y in 0..<rep.pixelsHigh {
                for x in 0..<rep.pixelsWide {
                    guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    if color.blueComponent > color.redComponent + 0.05,
                       color.blueComponent > color.greenComponent + 0.03 {
                        count += 1
                    }
                }
            }
            return count
        }

        XCTAssertEqual(0, try bluePixels(), "nothing is highlighted before the focus arrives")
        editor.focusHandler?(true)
        XCTAssertGreaterThan(try bluePixels(), 100,
                             "the ring must be painted (" + "\(frame.focusRingOpacity))")
        editor.focusHandler?(false)
        XCTAssertEqual(0, try bluePixels(), "the ring disappears with the focus")
    }

    /// Single-line fields use a rounded bezel, so both windows match.
    func testSingleLineFieldsUseARoundedBezel() throws {
        let document = DiagramDocument.newDocument()
        let first = ClassNode()
        first.setName("A")
        first.moveTo(Point(x: 10, y: 10))
        let second = ClassNode()
        second.setName("B")
        second.moveTo(Point(x: 10, y: 200))
        document.session.diagram.addRootNode(first)
        document.session.diagram.addRootNode(second)
        let edge = DependencyEdge()
        edge.connect(first, second)
        document.session.diagram.addEdge(edge)
        document.session.canvasController.setSelection(edge)
        let sheet = try XCTUnwrap(PropertySheetWindow(
            controller: document.session.canvasController, onChange: {}))

        var fields = 0
        for name in [PropertyName.middleLabel, .startLabel, .endLabel] {
            guard let field = sheet.textField(for: name) else { continue }
            fields += 1
            XCTAssertTrue(field.isBezeled)
            XCTAssertEqual(.roundedBezel, field.bezelStyle, "\(name) must be rounded")
            XCTAssertEqual(.default, field.focusRingType, "\(name) must show the blue focus ring")
        }
        XCTAssertGreaterThan(fields, 0, "a line has single-line text fields")
    }

    /// The labels are only for display: the file format keeps the original names.
    func testExternalNamesStayUntouched() {
        XCTAssertEqual("attributes", PropertyName.attributes.external)
        XCTAssertEqual("middleLabel", PropertyName.middleLabel.external)
        XCTAssertEqual("openBottom", PropertyName.openBottom.external)
        XCTAssertEqual("Attributes", PropertyName.attributes.visible)
        XCTAssertEqual("Middle Label", PropertyName.middleLabel.visible)
    }
}
