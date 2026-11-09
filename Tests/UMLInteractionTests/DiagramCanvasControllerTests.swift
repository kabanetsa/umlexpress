import XCTest
@testable import UMLGeometry
@testable import UMLInteraction
@testable import UMLModel
@testable import UMLOperations
@testable import UMLRendering
@testable import UMLValidation

/// Tests for the headless canvas controller: tool use, selection, dragging, lasso,
/// rubber-band edge creation, deletion, undo/redo and clipboard operations.
final class DiagramCanvasControllerTests: XCTestCase {

    private var diagram: Diagram!
    private var builder: ClassDiagramBuilder!
    private var controller: DiagramCanvasController!
    private var notifications: [String] = []

    override func setUp() {
        super.setUp()
        diagram = Diagram(kind: .class)
        builder = ClassDiagramBuilder(diagram)
        controller = DiagramCanvasController(builder: builder, validator: ClassDiagramValidator(diagram),
                                            width: 1000, height: 1000)
        notifications = []
        controller.notificationHandler = { [weak self] message in self?.notifications.append(message) }
    }

    /// Adds a class node with a fixed size through the renderer's default dimension.
    @discardableResult
    private func addClassNode(named name: String, at point: Point) -> ClassNode {
        let node = ClassNode()
        node.setName(name)
        node.moveTo(point)
        diagram.addRootNode(node)
        return node
    }

    // MARK: - Node creation

    func testCreateNodeWithTool() {
        controller.selectTool(ClassNode())
        XCTAssertTrue(controller.creationPrototype is ClassNode)

        controller.mousePressed(at: Point(x: 37, y: 41))
        controller.mouseReleased(at: Point(x: 37, y: 41))

        XCTAssertEqual(1, diagram.rootNodes.count)
        let node = diagram.rootNodes[0]
        // The position is snapped to the 10px grid.
        XCTAssertEqual(Point(x: 40, y: 40), node.position)
        XCTAssertTrue(controller.selection.count == 1)
        XCTAssertTrue(controller.selection[0] === node)
        XCTAssertTrue(controller.hasUnsavedChanges)
    }

    func testCreateNodeOnTopOfNodeSelectsInstead() {
        let existing = addClassNode(named: "A", at: Point(x: 0, y: 0))
        controller.selectTool(ClassNode())
        // The class node renders as a 100x60 box, so this point is inside it.
        controller.mousePressed(at: Point(x: 50, y: 30))
        controller.mouseReleased(at: Point(x: 50, y: 30))
        XCTAssertEqual(1, diagram.rootNodes.count, "no new node is created")
        XCTAssertTrue(controller.selection[0] === existing)
    }

    func testCreateNodeInsidePackageIsAllowed() {
        let package = PackageNode()
        package.setName("P")
        package.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(package)

        controller.selectTool(ClassNode())
        controller.mousePressed(at: Point(x: 40, y: 60))
        controller.mouseReleased(at: Point(x: 40, y: 60))

        XCTAssertEqual(1, package.children.count, "the class is added inside the package")
    }

    func testInvalidNodeCreationIsRolledBack() {
        // A point node with no edge is structurally invalid, so the creation is undone.
        controller.selectTool(PointNode())
        controller.mousePressed(at: Point(x: 100, y: 100))
        controller.mouseReleased(at: Point(x: 100, y: 100))

        XCTAssertTrue(diagram.rootNodes.isEmpty, "the invalid creation is undone")
        XCTAssertEqual(1, notifications.count)
        XCTAssertFalse(controller.hasUnsavedChanges)
    }

    // MARK: - Selection

    func testClickSelectsAndCtrlTogglesSelection() {
        let first = addClassNode(named: "A", at: Point(x: 0, y: 0))
        let second = addClassNode(named: "B", at: Point(x: 0, y: 200))

        controller.mousePressed(at: Point(x: 50, y: 30))
        XCTAssertTrue(controller.selection.count == 1 && controller.selection[0] === first)

        controller.mouseReleased(at: Point(x: 50, y: 30))
        controller.mousePressed(at: Point(x: 50, y: 230), modifiers: .control)
        XCTAssertEqual(2, controller.selection.count)

        controller.mouseReleased(at: Point(x: 50, y: 230))
        controller.mousePressed(at: Point(x: 50, y: 230), modifiers: .control)
        XCTAssertEqual(1, controller.selection.count, "ctrl-click toggles the element off")
    }

    func testClickOnEmptyAreaClearsSelection() {
        addClassNode(named: "A", at: Point(x: 0, y: 0))
        controller.setSelection(diagram.rootNodes[0])
        controller.mousePressed(at: Point(x: 500, y: 500))
        XCTAssertTrue(controller.selection.isEmpty)
    }

    func testSelectAll() {
        addClassNode(named: "A", at: Point(x: 0, y: 0))
        addClassNode(named: "B", at: Point(x: 0, y: 200))
        controller.selectAll()
        XCTAssertEqual(2, controller.selection.count)
    }

    // MARK: - Moving

    func testDragMovesSelectionAndSnapsToGrid() {
        let node = addClassNode(named: "A", at: Point(x: 0, y: 0))
        controller.mousePressed(at: Point(x: 50, y: 30))
        controller.mouseDragged(to: Point(x: 80, y: 60))
        controller.mouseReleased(at: Point(x: 80, y: 60))

        // Moved by (30, 30) and then aligned to the grid.
        XCTAssertEqual(Point(x: 30, y: 30), node.position)
        XCTAssertTrue(controller.canUndo)
        controller.undo()
        XCTAssertEqual(Point(x: 0, y: 0), node.position)
    }

    func testDragIsClampedToCanvas() {
        let node = addClassNode(named: "A", at: Point(x: 800, y: 900))
        controller.mousePressed(at: Point(x: 850, y: 930))
        controller.mouseDragged(to: Point(x: 1200, y: 1200))
        controller.mouseReleased(at: Point(x: 1200, y: 1200))
        // The canvas is 1000x1000 and the node box is 100x60.
        XCTAssertLessThanOrEqual(node.position.x + 100, 1000)
        XCTAssertLessThanOrEqual(node.position.y + 60, 1000)
    }

    // MARK: - Lasso

    func testLassoSelectsMultipleNodes() {
        let first = addClassNode(named: "A", at: Point(x: 0, y: 0))
        let second = addClassNode(named: "B", at: Point(x: 0, y: 120))
        addClassNode(named: "C", at: Point(x: 600, y: 600))

        // A lasso around the first two nodes only.
        controller.mousePressed(at: Point(x: 200, y: 250))
        controller.mouseDragged(to: Point(x: -10, y: -10))
        controller.mouseReleased(at: Point(x: -10, y: -10))

        XCTAssertEqual(2, controller.selection.count)
        XCTAssertTrue(controller.selection.contains { $0 === first })
        XCTAssertTrue(controller.selection.contains { $0 === second })
    }

    // MARK: - Edges

    func testRubberbandCreatesEdge() {
        let first = addClassNode(named: "A", at: Point(x: 0, y: 0))
        let second = addClassNode(named: "B", at: Point(x: 0, y: 200))

        controller.selectTool(GeneralizationEdge(.inheritance))
        controller.mousePressed(at: Point(x: 50, y: 30))
        XCTAssertEqual(.rubberband, controller.currentDragMode)
        controller.mouseDragged(to: Point(x: 50, y: 230))
        XCTAssertNotNil(controller.rubberbandLine)
        controller.mouseReleased(at: Point(x: 50, y: 230))

        XCTAssertEqual(1, diagram.edges.count)
        let edge = diagram.edges[0]
        XCTAssertTrue(edge.start() === first)
        XCTAssertTrue(edge.end() === second)
        XCTAssertTrue(controller.selection[0] === edge)
    }

    func testTinyDragDoesNotCreateEdge() {
        addClassNode(named: "A", at: Point(x: 0, y: 0))
        controller.selectTool(GeneralizationEdge(.inheritance))
        controller.mousePressed(at: Point(x: 50, y: 30))
        controller.mouseReleased(at: Point(x: 51, y: 31))
        XCTAssertTrue(diagram.edges.isEmpty)
    }

    func testInvalidEdgeIsRolledBack() {
        let first = addClassNode(named: "A", at: Point(x: 0, y: 0))
        // A self-generalization is a semantic violation.
        controller.selectTool(GeneralizationEdge(.inheritance))
        controller.mousePressed(at: Point(x: 20, y: 20))
        controller.mouseDragged(to: Point(x: 80, y: 50))
        controller.mouseReleased(at: Point(x: 80, y: 50))

        XCTAssertTrue(diagram.edges.isEmpty, "the invalid edge is undone")
        XCTAssertEqual(1, notifications.count, "the user was notified")
        XCTAssertTrue(first === diagram.rootNodes[0])
    }

    // MARK: - Commands

    func testDeleteRemovesSelection() {
        let node = addClassNode(named: "A", at: Point(x: 0, y: 0))
        controller.setSelection(node)
        controller.removeSelected()
        XCTAssertTrue(diagram.rootNodes.isEmpty)
        controller.undo()
        XCTAssertEqual(1, diagram.rootNodes.count)
    }

    func testUndoRedoKeepsSelectionConsistent() {
        controller.selectTool(ClassNode())
        controller.mousePressed(at: Point(x: 10, y: 10))
        controller.mouseReleased(at: Point(x: 10, y: 10))
        XCTAssertEqual(1, diagram.rootNodes.count)

        controller.undo()
        XCTAssertTrue(diagram.rootNodes.isEmpty)
        XCTAssertTrue(controller.selection.isEmpty)

        controller.redo()
        XCTAssertEqual(1, diagram.rootNodes.count)
    }

    func testHasUnsavedChangesTracksSave() {
        controller.selectTool(ClassNode())
        controller.mousePressed(at: Point(x: 10, y: 10))
        controller.mouseReleased(at: Point(x: 10, y: 10))
        XCTAssertTrue(controller.hasUnsavedChanges)
        controller.diagramSaved()
        XCTAssertFalse(controller.hasUnsavedChanges)
    }

    // MARK: - Clipboard

    func testCopyPasteDuplicatesElements() {
        let first = addClassNode(named: "A", at: Point(x: 0, y: 0))
        let second = addClassNode(named: "B", at: Point(x: 0, y: 200))
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(first, second)
        diagram.addEdge(edge)

        controller.setSelection([first, second, edge])
        controller.copy()
        XCTAssertEqual(3, controller.clipboard.count)

        controller.paste()
        XCTAssertEqual(4, diagram.rootNodes.count)
        XCTAssertEqual(2, diagram.edges.count)
        // The pasted edge is connected to the pasted nodes, not the originals.
        let pastedEdge = diagram.edges[1]
        XCTAssertFalse(pastedEdge.start() === first)
        XCTAssertTrue(diagram.contains(pastedEdge.start()!))
    }

    func testCutRemovesSelection() {
        let node = addClassNode(named: "A", at: Point(x: 0, y: 0))
        controller.setSelection(node)
        controller.cut()
        XCTAssertTrue(diagram.rootNodes.isEmpty)
        XCTAssertEqual(1, controller.clipboard.count)
        controller.paste()
        XCTAssertEqual(1, diagram.rootNodes.count)
    }

    func testPasteWithoutContentDoesNothing() {
        controller.paste()
        XCTAssertTrue(diagram.rootNodes.isEmpty)
    }
}

/// The sequence layout must survive a diagram that changes between two draws.
///
/// Reproduces a crash reported from the application: drawing a call edge creates call
/// nodes, and the very next `diagramBounds()` (as the canvas view asks for one) looked up
/// positions in a stale layout and trapped on a missing entry.
final class SequenceLayoutRobustnessTests: XCTestCase {

    private var diagram: Diagram!
    private var builder: SequenceDiagramBuilder!
    private var controller: DiagramCanvasController!

    override func setUp() {
        super.setUp()
        diagram = Diagram(kind: .sequence)
        builder = SequenceDiagramBuilder(diagram)
        controller = DiagramCanvasController(builder: builder,
                                            validator: SequenceDiagramValidator(diagram),
                                            width: 2000, height: 1000)
    }

    private func addParameter(named name: String, at point: Point) -> ImplicitParameterNode {
        let node = ImplicitParameterNode()
        node.setName(name)
        node.moveTo(point)
        diagram.addRootNode(node)
        return node
    }

    /// Drags a call edge from inside one lifeline head to another, as the canvas does.
    private func drawCallEdge(from start: Point, to end: Point) {
        controller.selectTool(CallEdge())
        controller.mousePressed(at: start)
        controller.mouseDragged(to: end)
        controller.mouseReleased(at: end)
    }

    /// The view recomputes the canvas extent (and therefore the diagram bounds) on every
    /// change; that path used to crash.
    func testDiagramBoundsAfterCreatingCallEdges() {
        let left = addParameter(named: "client", at: Point(x: 100, y: 100))
        let right = addParameter(named: "server", at: Point(x: 500, y: 100))
        var boundsRequests = 0
        controller.changeHandler = { [unowned self] in
            boundsRequests += 1
            _ = self.controller.renderer.diagramBounds()
        }

        drawCallEdge(from: Point(x: left.position.x + 40, y: left.position.y + 20),
                     to: Point(x: right.position.x + 40, y: right.position.y + 20))
        XCTAssertGreaterThan(boundsRequests, 0, "the change handler must have run")
        XCTAssertFalse(right.children.isEmpty, "the call edge must create a call node")

        // A second call, now from the call node of the first one: the layout is stale at
        // this point unless it is recomputed.
        drawCallEdge(from: Point(x: right.position.x + 40, y: right.position.y + 30),
                     to: Point(x: left.position.x + 40, y: left.position.y + 20))

        let bounds = controller.renderer.diagramBounds()
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }

    /// A call node that the call tree does not reach still gets a position.
    func testOrphanCallNodeIsLaidOut() {
        let parameter = addParameter(named: "client", at: Point(x: 100, y: 100))
        let orphan = CallNode()
        parameter.addChild(orphan)

        let bounds = controller.renderer.diagramBounds()
        XCTAssertGreaterThan(bounds.height, 0)
        let renderer = try? XCTUnwrap(controller.renderer as? SequenceDiagramRenderer)
        XCTAssertGreaterThan(renderer?.y(orphan) ?? 0, 0, "the orphan must have a y-coordinate")
        XCTAssertGreaterThan(renderer?.maxY(orphan) ?? 0, renderer?.y(orphan) ?? 0)
    }
}
