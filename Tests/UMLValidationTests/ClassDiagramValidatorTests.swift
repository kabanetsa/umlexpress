import XCTest
@testable import UMLModel
@testable import UMLValidation

/// Port of test/org/jetuml/diagram/validator/ClassDiagramValidatorTest.java
final class ClassDiagramValidatorTests: XCTestCase {

    private var classNode1 = ClassNode()
    private var classNode2 = ClassNode()
    private var interfaceNode = InterfaceNode()
    private var diagram = Diagram(kind: .class)

    override func setUp() {
        super.setUp()
        classNode1 = ClassNode()
        classNode2 = ClassNode()
        interfaceNode = InterfaceNode()
        diagram = Diagram(kind: .class)
    }

    private func connect<T: Edge>(_ edge: T, _ start: any Node, _ end: any Node) -> T {
        edge.connect(start, end)
        diagram.addEdge(edge)
        return edge
    }

    func testEmptyDiagramIsValid() {
        XCTAssertTrue(ClassDiagramValidator(diagram).isValid)
    }

    func testSimpleValidDiagram() {
        diagram.addRootNode(classNode1)
        diagram.addRootNode(interfaceNode)
        _ = connect(GeneralizationEdge(.implementation), classNode1, interfaceNode)
        _ = connect(AssociationEdge(), classNode1, classNode1)
        XCTAssertTrue(ClassDiagramValidator(diagram).isValid)
    }

    func testInvalidNodeType() {
        diagram.addRootNode(ActorNode())
        let violation = ClassDiagramValidator(diagram).validate()
        XCTAssertEqual(.structural("StructureInvalidElements"), violation)
    }

    func testInvalidEdgeType() {
        diagram.addRootNode(classNode1)
        diagram.addRootNode(classNode2)
        _ = connect(StateTransitionEdge(), classNode1, classNode2)
        XCTAssertEqual(.structural("StructureInvalidElements"), ClassDiagramValidator(diagram).validate())
    }

    func testSelfGeneralizationIsSemanticViolation() {
        diagram.addRootNode(classNode1)
        _ = connect(GeneralizationEdge(.inheritance), classNode1, classNode1)
        let violation = ClassDiagramValidator(diagram).validate()
        XCTAssertEqual(.semantic(ConstraintNoSelfEdgeForEdgeType(GeneralizationEdge.self)), violation)
        XCTAssertTrue(violation?.isSemantic ?? false)
    }

    func testSelfDependencyIsSemanticViolation() {
        diagram.addRootNode(classNode1)
        _ = connect(DependencyEdge(), classNode1, classNode1)
        XCTAssertEqual(.semantic(ConstraintNoSelfEdgeForEdgeType(DependencyEdge.self)),
                       ClassDiagramValidator(diagram).validate())
    }

    func testSelfAssociationIsValid() {
        diagram.addRootNode(classNode1)
        _ = connect(AssociationEdge(), classNode1, classNode1)
        XCTAssertNil(ClassDiagramValidator(diagram).validate())
    }

    func testDirectCycleOfGeneralizations() {
        diagram.addRootNode(classNode1)
        diagram.addRootNode(classNode2)
        _ = connect(GeneralizationEdge(.inheritance), classNode1, classNode2)
        _ = connect(GeneralizationEdge(.inheritance), classNode2, classNode1)
        XCTAssertEqual(.semantic(ConstraintNoDirectCyclesForEdgeType(GeneralizationEdge.self)),
                       ClassDiagramValidator(diagram).validate())
    }

    func testDirectCycleOfDependencies() {
        diagram.addRootNode(classNode1)
        diagram.addRootNode(classNode2)
        _ = connect(DependencyEdge(), classNode1, classNode2)
        _ = connect(DependencyEdge(), classNode2, classNode1)
        XCTAssertEqual(.semantic(ConstraintNoDirectCyclesForEdgeType(DependencyEdge.self)),
                       ClassDiagramValidator(diagram).validate())
    }

    func testSingleDependencyIsValid() {
        diagram.addRootNode(classNode1)
        diagram.addRootNode(classNode2)
        _ = connect(DependencyEdge(), classNode1, classNode2)
        XCTAssertNil(ClassDiagramValidator(diagram).validate())
    }

    func testTooManyEdgesOfTheSameTypeBetweenNodes() {
        diagram.addRootNode(classNode1)
        diagram.addRootNode(classNode2)
        _ = connect(DependencyEdge(), classNode1, classNode2)
        _ = connect(DependencyEdge(), classNode1, classNode2)
        XCTAssertEqual(.semantic(ConstraintMaxNumberOfEdgesOfGivenTypeBetweenNodes(1)),
                       ClassDiagramValidator(diagram).validate())
    }

    func testCombinedAssociationAndAggregation() {
        diagram.addRootNode(classNode1)
        diagram.addRootNode(classNode2)
        _ = connect(AssociationEdge(), classNode1, classNode2)
        _ = connect(AggregationEdge(.aggregation), classNode2, classNode1)
        XCTAssertEqual(.semantic(ConstraintNoCombinedAssociationAggregation()),
                       ClassDiagramValidator(diagram).validate())
    }

    func testNoteEdgeToPointNodeIsValid() {
        let note = NoteNode()
        let point = PointNode()
        diagram.addRootNode(note)
        diagram.addRootNode(point)
        _ = connect(NoteEdge(), note, point)
        XCTAssertNil(ClassDiagramValidator(diagram).validate())
    }

    func testNoteEdgeFromClassToNoteIsValid() {
        let note = NoteNode()
        diagram.addRootNode(classNode1)
        diagram.addRootNode(note)
        _ = connect(NoteEdge(), classNode1, note)
        XCTAssertNil(ClassDiagramValidator(diagram).validate())
    }

    func testNoteEdgeFromNoteToClassIsInvalid() {
        let note = NoteNode()
        diagram.addRootNode(classNode1)
        diagram.addRootNode(note)
        _ = connect(NoteEdge(), note, classNode1)
        XCTAssertEqual(.semantic(ConstraintValidNoteEdge()), ClassDiagramValidator(diagram).validate())
    }

    func testNonNoteEdgeToNoteIsInvalid() {
        let note = NoteNode()
        diagram.addRootNode(classNode1)
        diagram.addRootNode(note)
        _ = connect(DependencyEdge(), classNode1, note)
        let violation = ClassDiagramValidator(diagram).validate()
        XCTAssertTrue(violation?.isSemantic ?? false)
    }

    func testUnconnectedPointNodeIsStructuralViolation() {
        diagram.addRootNode(PointNode())
        XCTAssertEqual(.structural("StructureInvalidPoints"), ClassDiagramValidator(diagram).validate())
    }

    func testValidatorRejectsWrongDiagramKind() {
        // A class diagram with a sequence-only node is structurally invalid.
        let diagram = Diagram(kind: .class)
        diagram.addRootNode(ImplicitParameterNode())
        XCTAssertEqual(.structural("StructureInvalidElements"), ClassDiagramValidator(diagram).validate())
    }
}
