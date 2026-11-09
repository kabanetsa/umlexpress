import XCTest
@testable import UMLGeometry
@testable import UMLInteraction
@testable import UMLModel
@testable import UMLOperations
@testable import UMLRendering
@testable import UMLValidation

/// Tests for the property sheet model (port of `PropertySheet`).
final class PropertySheetModelTests: XCTestCase {

    func testClassNodeRows() {
        let node = ClassNode()
        node.setName("Figure")
        node.setAttributes("id:int")
        node.setMethods("draw():void")
        let model = PropertySheetModel(element: node)

        XCTAssertEqual([.name, .attributes, .methods], model.rows.map(\.name))
        XCTAssertEqual(["Figure", "id:int", "draw():void"], model.rows.map(\.value))
        // Class nodes use multi-line editors for their text.
        XCTAssertEqual([.multilineText, .multilineText, .multilineText], model.rows.map(\.kind))
    }

    func testNoteNodeNameIsLabelledText() {
        let note = NoteNode()
        note.setName("a note")
        let model = PropertySheetModel(element: note)
        XCTAssertEqual(1, model.rows.count)
        XCTAssertEqual("Text", model.rows[0].label)
        XCTAssertEqual(.multilineText, model.rows[0].kind)
    }

    func testEnumerationEditors() {
        let aggregation = AggregationEdge()
        let model = PropertySheetModel(element: aggregation)
        let row = model.rows.first { $0.name == .aggregationType }
        XCTAssertEqual(.choice(["Aggregation", "Composition"]), row?.kind)
        XCTAssertEqual("Aggregation", row?.value)

        let association = AssociationEdge()
        let associationRow = PropertySheetModel(element: association).rows
            .first { $0.name == .directionality }
        XCTAssertEqual(.choice(["Unspecified", "Unidirectional", "Bidirectional"]), associationRow?.kind)

        // A dependency only allows two directionalities.
        let dependency = DependencyEdge()
        let dependencyRow = PropertySheetModel(element: dependency).rows
            .first { $0.name == .directionality }
        XCTAssertEqual(.choice(["Unidirectional", "Bidirectional"]), dependencyRow?.kind)

        let generalization = GeneralizationEdge()
        XCTAssertEqual(.choice(["Inheritance", "Implementation"]),
                       PropertySheetModel(element: generalization).rows
                        .first { $0.name == .generalizationType }?.kind)
    }

    func testBooleanEditor() {
        let callNode = CallNode()
        callNode.setOpenBottom(true)
        let model = PropertySheetModel(element: callNode)
        XCTAssertEqual(.boolean, model.rows[0].kind)
        XCTAssertEqual("true", model.rows[0].value)
    }

    func testSetValueIsUndoable() {
        let node = ClassNode()
        node.setName("A")
        let model = PropertySheetModel(element: node)

        let operation = model.setValue("B", for: .name)
        operation.execute()
        XCTAssertEqual("B", node.name)
        XCTAssertEqual("B", model.rows[0].value)

        operation.undo()
        XCTAssertEqual("A", node.name)
    }

    func testSetEnumerationValue() {
        let edge = AggregationEdge()
        let model = PropertySheetModel(element: edge)
        let operation = model.setValue("Composition", for: .aggregationType)
        operation.execute()
        XCTAssertEqual(.composition, edge.type)
        XCTAssertEqual(edge.properties.string(.aggregationType), "Composition")
        operation.undo()
        XCTAssertEqual(.aggregation, edge.type)
    }

    func testSetBooleanValue() {
        let callNode = CallNode()
        let model = PropertySheetModel(element: callNode)
        let operation = model.setValue("true", for: .openBottom)
        operation.execute()
        XCTAssertTrue(callNode.isOpenBottom)
        operation.undo()
        XCTAssertFalse(callNode.isOpenBottom)
    }

    func testEmptyForEdgelessProperties() {
        let noteEdge = NoteEdge()
        XCTAssertTrue(PropertySheetModel(element: noteEdge).isEmpty)
    }

    func testControllerIntegration() {
        let diagram = Diagram(kind: .class)
        let builder = ClassDiagramBuilder(diagram)
        let controller = DiagramCanvasController(builder: builder,
                                                 validator: ClassDiagramValidator(diagram))
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 10, y: 10))
        diagram.addRootNode(node)

        XCTAssertNil(controller.propertySheetModel(), "nothing selected")

        controller.setSelection(node)
        let model = controller.propertySheetModel()
        XCTAssertNotNil(model)
        XCTAssertEqual("A", model?.rows.first?.value)

        // Property changes go through the undo stack.
        let operation = model!.setValue("Renamed", for: .name)
        controller.applyPropertyChange(operation)
        XCTAssertEqual("Renamed", node.name)
        XCTAssertTrue(controller.canUndo)
        controller.undo()
        XCTAssertEqual("A", node.name)
    }
}

/// The live-apply / single-undo behaviour of the property dialog
/// (port of `PropertyEditorDialog.PropertyChangeTracker`).
final class PropertyEditingSessionTests: XCTestCase {

    func testLiveApplyDoesNotRecordOperations() {
        let node = ClassNode()
        let model = PropertySheetModel(element: node)
        let controllerDiagram = Diagram(kind: .class)
        let builder = ClassDiagramBuilder(controllerDiagram)
        let controller = DiagramCanvasController(builder: builder,
                                                validator: ClassDiagramValidator(controllerDiagram))
        controllerDiagram.addRootNode(node)
        controller.setSelection(node)

        model.setRawValue("Draft", for: .name)
        XCTAssertEqual("Draft", node.name, "the value is applied as it is typed")
        XCTAssertFalse(controller.canUndo, "typing does not create undo steps")
    }

    func testOperationSinceSnapshotDescribesAllChanges() {
        let node = ClassNode()
        node.setName("A")
        node.setMethods("m()")
        let model = PropertySheetModel(element: node)
        let snapshot = model.snapshot()

        model.setRawValue("B", for: .name)
        model.setRawValue("n()", for: .methods)
        let operation = model.operation(since: snapshot)

        XCTAssertEqual(2, operation.count, "one sub-operation per changed property")

        operation.execute()
        XCTAssertEqual("B", node.name)
        XCTAssertEqual("n()", node.methods)
        operation.undo()
        XCTAssertEqual("A", node.name)
        XCTAssertEqual("m()", node.methods)
    }

    func testUnchangedSessionProducesEmptyOperation() {
        let node = ClassNode()
        node.setName("A")
        let model = PropertySheetModel(element: node)
        let snapshot = model.snapshot()
        model.setRawValue("A", for: .name)
        XCTAssertTrue(model.operation(since: snapshot).isEmpty)
    }

    func testCommitRegistersSingleUndoStep() {
        let diagram = Diagram(kind: .class)
        let builder = ClassDiagramBuilder(diagram)
        let controller = DiagramCanvasController(builder: builder,
                                                validator: ClassDiagramValidator(diagram))
        let node = ClassNode()
        node.setName("A")
        diagram.addRootNode(node)
        controller.setSelection(node)

        let model = PropertySheetModel(element: node)
        let snapshot = model.snapshot()
        model.setRawValue("Renamed", for: .name)
        model.setRawValue("id:int", for: .attributes)
        let operation = model.operation(since: snapshot)
        controller.storeAlreadyAppliedPropertyChange(operation)

        XCTAssertTrue(controller.canUndo)
        XCTAssertEqual("Renamed", node.name)
        controller.undo()
        XCTAssertEqual("A", node.name)
        XCTAssertEqual("", node.attributes)
        XCTAssertFalse(controller.canUndo, "one undo reverts the whole editing session")
    }
}
