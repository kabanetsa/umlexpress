import XCTest
@testable import UMLGeometry
@testable import UMLModel
@testable import UMLOperations
@testable import UMLRendering

/// Port of test/org/jetuml/diagram/builder/DiagramOperationProcessorTest.java and of the
/// class-diagram builder scenarios.
final class OperationsTests: XCTestCase {

    // MARK: - Undo / redo bookkeeping

    func testProcessorExecutesAndUndoes() {
        var value = 0
        let processor = DiagramOperationProcessor()
        processor.executeNewOperation(SimpleOperation({ value += 1 }, reverse: { value -= 1 }))
        XCTAssertEqual(1, value)
        XCTAssertTrue(processor.canUndo)
        XCTAssertFalse(processor.canRedo)

        processor.undoLastExecutedOperation()
        XCTAssertEqual(0, value)
        XCTAssertFalse(processor.canUndo)
        XCTAssertTrue(processor.canRedo)

        processor.redoLastUndoneOperation()
        XCTAssertEqual(1, value)
        XCTAssertTrue(processor.canUndo)
        XCTAssertFalse(processor.canRedo)
    }

    func testUnsavedOperations() {
        let processor = DiagramOperationProcessor()
        XCTAssertFalse(processor.hasUnsavedOperations())

        let first = SimpleOperation({}, reverse: {})
        processor.executeNewOperation(first)
        XCTAssertTrue(processor.hasUnsavedOperations())

        processor.diagramSaved()
        XCTAssertFalse(processor.hasUnsavedOperations())

        processor.executeNewOperation(SimpleOperation({}, reverse: {}))
        XCTAssertTrue(processor.hasUnsavedOperations())

        // Undoing back to the saved state makes the diagram clean again.
        processor.undoLastExecutedOperation()
        XCTAssertFalse(processor.hasUnsavedOperations(), "the saved state is reached again")

        // Undoing past it (no operations left) is reported as dirty, as in the original.
        processor.undoLastExecutedOperation()
        XCTAssertTrue(processor.hasUnsavedOperations(), "an empty history after a save is dirty")
    }

    func testStoreAlreadyExecutedOperation() {
        let processor = DiagramOperationProcessor()
        processor.storeAlreadyExecutedOperation(SimpleOperation({}, reverse: {}))
        XCTAssertTrue(processor.canUndo)
    }

    func testCompoundOperationOrder() {
        var log: [String] = []
        let compound = CompoundOperation()
        compound.add(SimpleOperation({ log.append("a") }, reverse: { log.append("-a") }))
        compound.add(SimpleOperation({ log.append("b") }, reverse: { log.append("-b") }))
        XCTAssertFalse(compound.isEmpty)
        XCTAssertEqual(2, compound.count)

        compound.execute()
        XCTAssertEqual(["a", "b"], log)

        log.removeAll()
        compound.undo()
        XCTAssertEqual(["-b", "-a"], log, "undo runs in reverse order")
    }

    // MARK: - Builder

    private var diagram: Diagram!
    private var builder: ClassDiagramBuilder!
    private var classNode: ClassNode!

    override func setUp() {
        super.setUp()
        diagram = Diagram(kind: .class)
        builder = ClassDiagramBuilder(diagram)
        classNode = ClassNode()
        classNode.setName("A")
    }

    func testAddNodeOperationIsUndoable() {
        let operation = builder.createAddNodeOperation(classNode, Point(x: 50, y: 60))
        operation.execute()
        XCTAssertTrue(diagram.containsAsRoot(classNode))
        XCTAssertEqual(Point(x: 50, y: 60), classNode.position)
        operation.undo()
        XCTAssertFalse(diagram.containsAsRoot(classNode))
    }

    func testAddNodeIsClampedToCanvas() {
        builder.setCanvasDimension(UMLGeometry.Dimension(width: 200, height: 150))
        let operation = builder.createAddNodeOperation(classNode, Point(x: 190, y: 140))
        operation.execute()
        // The node (100x60) is pulled back inside the canvas.
        XCTAssertEqual(Point(x: 100, y: 90), classNode.position)
    }

    func testAddEdgeOperationIsUndoable() {
        let first = ClassNode()
        first.moveTo(Point(x: 0, y: 0))
        let second = ClassNode()
        second.moveTo(Point(x: 0, y: 200))
        diagram.addRootNode(first)
        diagram.addRootNode(second)

        let edge = GeneralizationEdge(.inheritance)
        let operation = builder.createAddEdgeOperation(edge, Point(x: 50, y: 30), Point(x: 50, y: 230))
        operation.execute()

        XCTAssertEqual(1, diagram.edges.count)
        XCTAssertTrue(edge.start() === first)
        XCTAssertTrue(edge.end() === second)

        operation.undo()
        XCTAssertTrue(diagram.edges.isEmpty)
    }

    func testNoteEdgeCreatesPointNode() {
        let note = NoteNode()
        note.setName("a note")
        note.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(note)

        let operation = builder.createAddEdgeOperation(NoteEdge(), Point(x: 10, y: 10), Point(x: 300, y: 300))
        operation.execute()

        XCTAssertEqual(1, diagram.edges.count)
        XCTAssertNotNil(diagram.edges.first)
        XCTAssertTrue(diagram.edges.first?.end() is PointNode)
        XCTAssertEqual(2, diagram.rootNodes.count, "the point node becomes a root node")
    }

    func testRemoveNodeAlsoRemovesItsEdges() {
        let first = ClassNode()
        first.moveTo(Point(x: 0, y: 0))
        let second = ClassNode()
        second.moveTo(Point(x: 0, y: 200))
        diagram.addRootNode(first)
        diagram.addRootNode(second)
        let edge = GeneralizationEdge(.inheritance)
        edge.connect(first, second)
        diagram.addEdge(edge)

        let operation = builder.createRemoveElementsOperation([first])
        operation.execute()
        XCTAssertTrue(diagram.edges.isEmpty, "the edge must be removed with the node")
        XCTAssertEqual(1, diagram.rootNodes.count)

        operation.undo()
        XCTAssertEqual(2, diagram.rootNodes.count)
        XCTAssertEqual(1, diagram.edges.count)
    }

    func testRemoveChildOfPackageShrinksPackage() {
        let package = PackageNode()
        package.setName("P")
        package.moveTo(Point(x: 0, y: 0))
        let child = ClassNode()
        child.setName("C")
        diagram.addRootNode(package)
        package.addChild(child)

        let operation = builder.createRemoveElementsOperation([child])
        operation.execute()
        XCTAssertTrue(package.children.isEmpty)
        operation.undo()
        XCTAssertEqual(1, package.children.count)
        XCTAssertTrue(package.children[0] === child)
    }

    func testMoveNodeOperation() {
        classNode.moveTo(Point(x: 10, y: 10))
        let operation = DiagramBuilder.createMoveNodeOperation(classNode, 5, -3)
        operation.execute()
        XCTAssertEqual(Point(x: 15, y: 7), classNode.position)
        operation.undo()
        XCTAssertEqual(Point(x: 10, y: 10), classNode.position)
    }

    func testAddElementNodeToPackageUnderPoint() {
        let package = PackageNode()
        package.setName("P")
        package.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(package)

        let operation = builder.createAddNodeOperation(classNode, Point(x: 20, y: 60))
        operation.execute()
        XCTAssertTrue(package.children.contains { $0 === classNode })
        XCTAssertFalse(diagram.containsAsRoot(classNode))

        operation.undo()
        XCTAssertTrue(package.children.isEmpty)
    }

    func testAddElementsOperation() {
        let second = ClassNode()
        let edge = DependencyEdge()
        edge.connect(classNode, second)
        let operation = builder.createAddElementsOperation([classNode, second, edge])
        operation.execute()
        XCTAssertEqual(2, diagram.rootNodes.count)
        XCTAssertEqual(1, diagram.edges.count)
        operation.undo()
        XCTAssertTrue(diagram.rootNodes.isEmpty)
        XCTAssertTrue(diagram.edges.isEmpty)
    }

    func testLinkAndUnlinkPackage() {
        let package = PackageNode()
        package.setName("P")
        package.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(package)
        classNode.moveTo(Point(x: 10, y: 40))
        diagram.addRootNode(classNode)

        XCTAssertTrue(builder.canLinkToPackage([classNode]))
        let link = builder.createLinkToPackageOperation([classNode])
        link.execute()
        XCTAssertTrue(package.children.contains { $0 === classNode })
        XCTAssertFalse(diagram.containsAsRoot(classNode))

        link.undo()
        XCTAssertTrue(diagram.containsAsRoot(classNode))
        XCTAssertTrue(package.children.isEmpty)
    }

    func testUnlinkFromPackage() {
        let package = PackageNode()
        package.setName("P")
        package.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(package)
        classNode.moveTo(Point(x: 10, y: 40))
        package.addChild(classNode)

        XCTAssertTrue(builder.canUnlinkFromPackage([classNode]))
        let unlink = builder.createUnlinkFromPackageOperation([classNode])
        unlink.execute()
        XCTAssertTrue(diagram.containsAsRoot(classNode))
        XCTAssertTrue(package.children.isEmpty)

        unlink.undo()
        XCTAssertTrue(package.children.contains { $0 === classNode })
    }

    func testCanLinkRejectsNodesThatAreNotChildren() {
        let note = NoteNode()
        note.moveTo(Point(x: 0, y: 0))
        diagram.addRootNode(note)
        XCTAssertFalse(builder.canLinkToPackage([note]))
        XCTAssertFalse(builder.canLinkToPackage([]))
        XCTAssertFalse(builder.canUnlinkFromPackage([]))
    }
}
